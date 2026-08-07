# frozen_string_literal: true

require_relative "core"
require_relative "moon_elp"

module AstroChart
  module Pure
    # Moon — MIT-safe 純 Ruby 月球位置（零外部依賴）。
    #
    # 只使用公開文獻公式，不參考 Swiss Ephemeris C 原始碼：
    #   - 月球黃經/黃緯/距離：Jean Meeus, "Astronomical Algorithms" 2nd ed.,
    #     Ch. 47（ELP-2000/82 截斷級數：Table 47.A 60 項 + Table 47.B 60 項），
    #     再以公開發表的 ELP-2000/82B 級數（Chapront-Touzé & Chapront
    #     1983/1988, CDS VizieR VI/79）補充（moon_elp.rb）：
    #       * 主問題：Meeus 截斷線以下黃經 +197 項（至 0.005"）、
    #         黃緯 +221 項（至 0.002"）
    #       * 攝動：地球扁率（ELP4/5/8）+ 行星攝動 Table 1/2（ELP10/11/16/17），
    #         取代 Meeus 的 A1/A2/A3 加法捷徑（那些正是這些級數檔的最大列）
    #     補充後截斷誤差 < 0.1"（黃經）/ < 0.05"（黃緯）。
    #     實測 vs JPL Horizons（1972-11 近地點朔望，最惡條件）：黃經差 0.12"。
    #   - 視位置 = 幾何位置 + 章動 Δψ（Meeus Ch. 47 慣例；月亮距地近、
    #     光行差以「地心速度」定義對月球不適用，光行時 ~1.3s → ~0.0002°，
    #     在精度預算內忽略）。
    #   - 真（密切）北交點：由月球黃道直角座標 r 與中央差分速度 v 取
    #     角動量 h = r × v，升交點方向 n = ẑ × h = (−h_y, h_x, 0)，
    #     Ω = atan2(n_y, n_x) = atan2(h_x, −h_y)（標準軌道力學，如
    #     Vallado "Fundamentals of Astrodynamics"；黃道座標系）。
    #     與平均交點可差達 ±1.75°，不可混用。
    #
    # 精度註記（2026-07 驗證）：TRUE_NODE vs Swiss Ephemeris 全域（1900-2026
    # 每 2 天 dense 掃描）max ≈ 0.018°、mean ≈ 0.0026°。殘差尖峰集中在
    # 「近地點 + 朔望」時刻（誤差被 1/i ≈ 11 倍放大的敏感點），且已用
    # JPL Horizons 狀態向量獨立仲裁：本實作的密切交點與 Horizons 差
    # ~0.0006°，SE（內建 Moshier 類 fallback 星曆，月黃經實測差 Horizons
    # 1.75"）差 ~0.018° — 即殘差主要是 SE 側的近似誤差，繼續加項無法
    # 收斂（往 SE 誤差擬合反而踩授權線），此為此法的自然底線。
    #
    # 時間尺度慣例：公開 API 一律吃 **JD(UT)**，內部經 Core.jd_tt 換算 TT
    # 後代入級數（月亮 ~13°/day，ΔT ≈ 70s 就是 ~0.01°，不可省）。
    #
    # 公開 API（module_function，皆回傳 Float 度 [0,360)）：
    #   Moon.apparent_longitude(jd_ut) -> 月球視黃經（幾何 + Δψ）
    #   Moon.true_node(jd_ut)          -> 真北交點視黃經（密切 Ω + Δψ）
    #   Moon.geometric_position(jd_tt) -> [λ_deg, β_deg, Δ_km]（幾何，平春分點）
    module Moon
      # 中央差分步長（日）。0.005d ≈ 7.2 分鐘：對 27.3 天週期的軌道，
      # 二階截斷誤差 ~(2π·0.005/27.3)² ~ 1e-6，遠小於交點 0.02° 目標。
      NODE_DIFF_STEP_DAYS = 0.005

      # --- Meeus Table 47.A：黃經 Σl（單位 1e-6 度）與距離 Σr（單位 1e-3 km） ---
      # 各列 [D, M, M', F, l_coeff, r_coeff]；含 M 的項需乘 E^|M|（E 見 47.6）。
      LON_DIST_TERMS = [
        [0,  0,  1,  0,  6_288_774, -20_905_355],
        [2,  0, -1,  0,  1_274_027,  -3_699_111],
        [2,  0,  0,  0,    658_314,  -2_955_968],
        [0,  0,  2,  0,    213_618,    -569_925],
        [0,  1,  0,  0,   -185_116,      48_888],
        [0,  0,  0,  2,   -114_332,      -3_149],
        [2,  0, -2,  0,     58_793,     246_158],
        [2, -1, -1,  0,     57_066,    -152_138],
        [2,  0,  1,  0,     53_322,    -170_733],
        [2, -1,  0,  0,     45_758,    -204_586],
        [0,  1, -1,  0,    -40_923,    -129_620],
        [1,  0,  0,  0,    -34_720,     108_743],
        [0,  1,  1,  0,    -30_383,     104_755],
        [2,  0,  0, -2,     15_327,      10_321],
        [0,  0,  1,  2,    -12_528,           0],
        [0,  0,  1, -2,     10_980,      79_661],
        [4,  0, -1,  0,     10_675,     -34_782],
        [0,  0,  3,  0,     10_034,     -23_210],
        [4,  0, -2,  0,      8_548,     -21_636],
        [2,  1, -1,  0,     -7_888,      24_208],
        [2,  1,  0,  0,     -6_766,      30_824],
        [1,  0, -1,  0,     -5_163,      -8_379],
        [1,  1,  0,  0,      4_987,     -16_675],
        [2, -1,  1,  0,      4_036,     -12_831],
        [2,  0,  2,  0,      3_994,     -10_445],
        [4,  0,  0,  0,      3_861,     -11_650],
        [2,  0, -3,  0,      3_665,      14_403],
        [0,  1, -2,  0,     -2_689,      -7_003],
        [2,  0, -1,  2,     -2_602,           0],
        [2, -1, -2,  0,      2_390,      10_056],
        [1,  0,  1,  0,     -2_348,       6_322],
        [2, -2,  0,  0,      2_236,      -9_884],
        [0,  1,  2,  0,     -2_120,       5_751],
        [0,  2,  0,  0,     -2_069,           0],
        [2, -2, -1,  0,      2_048,      -4_950],
        [2,  0,  1, -2,     -1_773,       4_130],
        [2,  0,  0,  2,     -1_595,           0],
        [4, -1, -1,  0,      1_215,      -3_958],
        [0,  0,  2,  2,     -1_110,           0],
        [3,  0, -1,  0,       -892,       3_258],
        [2,  1,  1,  0,       -810,       2_616],
        [4, -1, -2,  0,        759,      -1_897],
        [0,  2, -1,  0,       -713,      -2_117],
        [2,  2, -1,  0,       -700,       2_354],
        [2,  1, -2,  0,        691,           0],
        [2, -1,  0, -2,        596,           0],
        [4,  0,  1,  0,        549,      -1_423],
        [0,  0,  4,  0,        537,      -1_117],
        [4, -1,  0,  0,        520,      -1_571],
        [1,  0, -2,  0,       -487,      -1_739],
        [2,  1,  0, -2,       -399,           0],
        [0,  0,  2, -2,       -381,      -4_421],
        [1,  1,  1,  0,        351,           0],
        [3,  0, -2,  0,       -340,           0],
        [4,  0, -3,  0,        330,           0],
        [2, -1,  2,  0,        327,           0],
        [0,  2,  1,  0,       -323,       1_165],
        [1,  1, -1,  0,        299,           0],
        [2,  0,  3,  0,        294,           0],
        [2,  0, -1, -2,          0,       8_752]
      ].freeze

      # --- Meeus Table 47.B：黃緯 Σb（單位 1e-6 度） ---
      # 各列 [D, M, M', F, b_coeff]；含 M 的項需乘 E^|M|。
      LAT_TERMS = [
        [0,  0,  0,  1,  5_128_122],
        [0,  0,  1,  1,    280_602],
        [0,  0,  1, -1,    277_693],
        [2,  0,  0, -1,    173_237],
        [2,  0, -1,  1,     55_413],
        [2,  0, -1, -1,     46_271],
        [2,  0,  0,  1,     32_573],
        [0,  0,  2,  1,     17_198],
        [2,  0,  1, -1,      9_266],
        [0,  0,  2, -1,      8_822],
        [2, -1,  0, -1,      8_216],
        [2,  0, -2, -1,      4_324],
        [2,  0,  1,  1,      4_200],
        [2,  1,  0, -1,     -3_359],
        [2, -1, -1,  1,      2_463],
        [2, -1,  0,  1,      2_211],
        [2, -1, -1, -1,      2_065],
        [0,  1, -1, -1,     -1_870],
        [4,  0, -1, -1,      1_828],
        [0,  1,  0,  1,     -1_794],
        [0,  0,  0,  3,     -1_749],
        [0,  1, -1,  1,     -1_565],
        [1,  0,  0,  1,     -1_491],
        [0,  1,  1,  1,     -1_475],
        [0,  1,  1, -1,     -1_410],
        [0,  1,  0, -1,     -1_344],
        [1,  0,  0, -1,     -1_335],
        [0,  0,  3,  1,      1_107],
        [4,  0,  0, -1,      1_021],
        [4,  0, -1,  1,        833],
        [0,  0,  1, -3,        777],
        [4,  0, -2,  1,        671],
        [2,  0,  0, -3,        607],
        [2,  0,  2, -1,        596],
        [2, -1,  1, -1,        491],
        [2,  0, -2,  1,       -451],
        [0,  0,  3, -1,        439],
        [2,  0,  2,  1,        422],
        [2,  0, -3, -1,        421],
        [2,  1, -1,  1,       -366],
        [2,  1,  0,  1,       -351],
        [4,  0,  0,  1,        331],
        [2, -1,  1,  1,        315],
        [2, -2,  0, -1,        302],
        [0,  0,  1,  3,       -283],
        [2,  1,  1, -1,       -229],
        [1,  1,  0, -1,        223],
        [1,  1,  0,  1,        223],
        [0,  1, -2, -1,       -220],
        [2,  1, -1, -1,       -220],
        [1,  0,  1,  1,       -185],
        [2, -1, -2, -1,        181],
        [0,  1,  2,  1,       -177],
        [4,  0, -2, -1,        176],
        [4, -1, -1, -1,        166],
        [1,  0,  1, -1,       -164],
        [4,  0,  1, -1,        132],
        [1,  0, -1, -1,       -119],
        [4, -1,  0, -1,        115],
        [2, -2,  0,  1,        107]
      ].freeze

      module_function

      # --- 月球視黃經（度，[0,360)）。引數 **JD(UT)**。 ---
      # 幾何黃經（平春分點 of date）+ 章動 Δψ = 視黃經（真春分點 of date）。
      def apparent_longitude(jd_ut)
        apparent_ecliptic(jd_ut)[0]
      end

      # Apparent geocentric ecliptic [longitude, latitude] in degrees. JD(UT).
      # ELP-2000 gives β directly; nutation shifts longitude only.
      def apparent_ecliptic(jd_ut)
        tt = Core.jd_tt(jd_ut)
        lam, beta, = geometric_position(tt)
        dpsi_deg, = Core.nutation(tt)
        [Core.norm360(lam + dpsi_deg), beta]
      end

      # --- 真（密切）北交點視黃經（度，[0,360)）。引數 **JD(UT)**。 ---
      # 由 r × v 的角動量向量取升交點方向；速度用 TT 上 ±NODE_DIFF_STEP_DAYS
      # 的中央差分。幾何 Ω（平春分點）+ Δψ = 視位置（真春分點），與
      # calc_ut 慣例一致。
      def true_node(jd_ut)
        tt = Core.jd_tt(jd_ut)
        r  = rectangular(tt)
        r1 = rectangular(tt - NODE_DIFF_STEP_DAYS)
        r2 = rectangular(tt + NODE_DIFF_STEP_DAYS)
        v = [
          (r2[0] - r1[0]) / (2.0 * NODE_DIFF_STEP_DAYS),
          (r2[1] - r1[1]) / (2.0 * NODE_DIFF_STEP_DAYS),
          (r2[2] - r1[2]) / (2.0 * NODE_DIFF_STEP_DAYS)
        ]
        # h = r × v（黃道直角座標，z 軸指向黃道北極）
        hx = r[1] * v[2] - r[2] * v[1]
        hy = r[2] * v[0] - r[0] * v[2]
        hz = r[0] * v[1] - r[1] * v[0]
        h_norm = Math.sqrt(hx * hx + hy * hy + hz * hz)
        raise Core::DomainError, "degenerate lunar angular momentum at JD(TT)=#{tt}" if h_norm.zero?

        # 升交點方向 n = ẑ × h = (−h_y, h_x, 0) → Ω = atan2(h_x, −h_y)
        omega = Math.atan2(hx, -hy) * Core::RAD2DEG
        dpsi_deg, = Core.nutation(tt)
        Core.norm360(omega + dpsi_deg)
      end

      # --- 幾何黃道座標（平春分點 of date）。引數 **JD(TT)**。 ---
      # 回傳 [λ_deg（未正規化前先算後 norm360）, β_deg, Δ_km]。
      # Meeus Ch. 47：λ = L' + Σl/1e6、β = Σb/1e6、Δ = 385000.56 + Σr/1e3。
      def geometric_position(jd_tt)
        t = (jd_tt - 2_451_545.0) / 36_525.0

        # 基本引數（Meeus 47.1–47.5，度）
        lp = 218.3164477 + 481_267.88123421 * t - 0.0015786 * t * t +
             t**3 / 538_841.0 - t**4 / 65_194_000.0
        d  = 297.8501921 + 445_267.1114034 * t - 0.0018819 * t * t +
             t**3 / 545_868.0 - t**4 / 113_065_000.0
        m  = 357.5291092 + 35_999.0502909 * t - 0.0001536 * t * t +
             t**3 / 24_490_000.0
        mp = 134.9633964 + 477_198.8675055 * t + 0.0087414 * t * t +
             t**3 / 69_699.0 - t**4 / 14_712_000.0
        f  = 93.2720950 + 483_202.0175233 * t - 0.0036539 * t * t -
             t**3 / 3_526_000.0 + t**4 / 863_310_000.0

        # 離心率修正 E（Meeus 47.6）
        e  = 1.0 - 0.002516 * t - 0.0000074 * t * t
        e2 = e * e

        d_rad  = d * Core::DEG2RAD
        m_rad  = m * Core::DEG2RAD
        mp_rad = mp * Core::DEG2RAD
        f_rad  = f * Core::DEG2RAD

        sum_l = 0.0
        sum_r = 0.0
        LON_DIST_TERMS.each do |cd, cm, cmp, cf, lc, rc|
          arg = cd * d_rad + cm * m_rad + cmp * mp_rad + cf * f_rad
          ecc = cm.zero? ? 1.0 : (cm.abs == 1 ? e : e2)
          sum_l += lc * ecc * Math.sin(arg)
          sum_r += rc * ecc * Math.cos(arg)
        end

        sum_b = 0.0
        LAT_TERMS.each do |cd, cm, cmp, cf, bc|
          arg = cd * d_rad + cm * m_rad + cmp * mp_rad + cf * f_rad
          ecc = cm.zero? ? 1.0 : (cm.abs == 1 ? e : e2)
          sum_b += bc * ecc * Math.sin(arg)
        end

        # ELP-2000/82 主問題補充項（moon_elp.rb；Meeus 截斷線以下）。
        # E 因子沿用 Meeus 慣例推廣為 E^|M|（補充項 |M| 最大 4）。
        SUPP_LON_TERMS.each do |cd, cm, cmp, cf, lc|
          arg = cd * d_rad + cm * m_rad + cmp * mp_rad + cf * f_rad
          ecc = cm.zero? ? 1.0 : e**cm.abs
          sum_l += lc * ecc * Math.sin(arg)
        end
        SUPP_LAT_TERMS.each do |cd, cm, cmp, cf, bc|
          arg = cd * d_rad + cm * m_rad + cmp * mp_rad + cf * f_rad
          ecc = cm.zero? ? 1.0 : e**cm.abs
          sum_b += bc * ecc * Math.sin(arg)
        end

        # 攝動項（moon_elp.rb：地球扁率 ELP4/5/8 + 行星攝動 ELP10/11/16/17）。
        # 取代 Meeus 的 A1/A2/A3 加法捷徑 — 那些捷徑正是這些級數檔的最大列
        # （A1 = 18V−16T−M'、A2/A3 同理），改用完整級數避免雙重計入。
        # ζ = W1 + p·t ≡ Meeus of-date L'（lp）；攝動振幅不乘 E 因子。
        sum_l += pert_sum(t, lp, d, m, mp, f,
                          PERT_LON_ZETA, PERT_LON_PLAN1, PERT_LON_PLAN2)
        sum_b += pert_sum(t, lp, d, m, mp, f,
                          PERT_LAT_ZETA, PERT_LAT_PLAN1, PERT_LAT_PLAN2)

        lam   = Core.norm360(lp + sum_l * 1.0e-6)
        beta  = sum_b * 1.0e-6
        delta = 385_000.56 + sum_r * 1.0e-3
        [lam, beta, delta]
      end

      # --- ELP 攝動級數求和（單位 1e-6 度）。內部方法。 ---
      # 引數皆為度：lp = ζ（≡ Meeus of-date L'）、d/m/mp/f = Delaunay。
      # zeta_terms:  [iz, iD, iM, iMp, iF, phase, coeff, tpow]
      # plan1_terms: [8 行星, iD, iMp, iF, phase, coeff]（Table 1 無 M）
      # plan2_terms: [7 行星, iD, iM, iMp, iF, phase, coeff]
      def pert_sum(t, lp, d, m, mp, f, zeta_terms, plan1_terms, plan2_terms)
        sum = 0.0

        zeta_terms.each do |iz, id_, im, imp, if_, pha, coeff, tpow|
          arg = pha + iz * lp + id_ * d + im * m + imp * mp + if_ * f
          x = coeff * Math.sin(arg * Core::DEG2RAD)
          sum += tpow == 1 ? x * t : x
        end

        planet = Array.new(8) do |i|
          base, rate = PLANETARY_ARGS[i]
          base + rate * t
        end

        plan1_terms.each do |p1, p2, p3, p4, p5, p6, p7, p8, id_, imp, if_, pha, coeff|
          arg = pha + p1 * planet[0] + p2 * planet[1] + p3 * planet[2] +
                p4 * planet[3] + p5 * planet[4] + p6 * planet[5] +
                p7 * planet[6] + p8 * planet[7] +
                id_ * d + imp * mp + if_ * f
          sum += coeff * Math.sin(arg * Core::DEG2RAD)
        end

        plan2_terms.each do |p1, p2, p3, p4, p5, p6, p7, id_, im, imp, if_, pha, coeff|
          arg = pha + p1 * planet[0] + p2 * planet[1] + p3 * planet[2] +
                p4 * planet[3] + p5 * planet[4] + p6 * planet[5] +
                p7 * planet[6] +
                id_ * d + im * m + imp * mp + if_ * f
          sum += coeff * Math.sin(arg * Core::DEG2RAD)
        end

        sum
      end

      # --- 黃道直角座標（平春分點 of date，km）。引數 **JD(TT)**。 ---
      def rectangular(jd_tt)
        lam, beta, delta = geometric_position(jd_tt)
        lam_rad  = lam * Core::DEG2RAD
        beta_rad = beta * Core::DEG2RAD
        cb = Math.cos(beta_rad)
        [
          delta * cb * Math.cos(lam_rad),
          delta * cb * Math.sin(lam_rad),
          delta * Math.sin(beta_rad)
        ]
      end
    end
  end
end
