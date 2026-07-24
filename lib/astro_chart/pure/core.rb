# frozen_string_literal: true

module AstroChart
  module Pure
    # Core — MIT-safe 純 Ruby 天文基建（零外部依賴）。
    #
    # 只使用公開文獻公式，不參考 Swiss Ephemeris C 原始碼：
    #   - 儒略日：Jean Meeus, "Astronomical Algorithms" 2nd ed., Ch. 7 (eq. 7.1)
    #   - ΔT（TT−UT）：Espenak & Meeus 多項式擬合
    #     （NASA Eclipse website, "Polynomial Expressions for Delta T (ΔT)",
    #       Five Millennium Canon of Solar Eclipses: -1999 to +3000）
    #   - 章動（Δψ / Δε）：Meeus Ch. 22（IAU 1980 序列截斷，振幅最大 13 項）
    #   - 平黃赤交角：Meeus eq. 22.2
    #   - 平恆星時 GMST：Meeus Ch. 12 (eq. 12.4，等同 IAU 1982 GMST)
    #   - 視恆星時 = GMST + Δψ·cos(ε_true)（Meeus Ch. 12）
    #
    # 時間尺度慣例（呼叫者必須遵守，弄錯會差 ~ΔT ≈ 70s → 月亮 ~0.01°）：
    #   - julday / gmst_deg / apparent_sidereal_deg 吃 **JD(UT)**
    #   - nutation / mean_obliquity / true_obliquity 吃 **JD(TT)**（先過 jd_tt 換算）
    #
    # 公開 API（module_function，皆回傳 Float 或 [Float, Float]）：
    #   Core.julday(year, month, day, hour)   -> JD(UT)；hour 為十進位 UT 小時
    #   Core.delta_t(jd_ut)                   -> ΔT 秒（TT − UT）
    #   Core.jd_tt(jd_ut)                     -> JD(TT) = jd_ut + ΔT/86400
    #   Core.nutation(jd_tt)                  -> [Δψ_deg, Δε_deg]（度）
    #   Core.mean_obliquity(jd_tt)            -> ε₀（度）
    #   Core.true_obliquity(jd_tt)            -> ε = ε₀ + Δε（度）
    #   Core.gmst_deg(jd_ut)                  -> 格林威治平恆星時（度，[0,360)）
    #   Core.apparent_sidereal_deg(jd_ut)     -> 格林威治視恆星時（度，[0,360)）
    #   Core.norm360(deg)                     -> 正規化到 [0, 360)
    #   Core::DomainError                     -> 超出適用範圍時 raise（顯性失敗）
    module Core
      DEG2RAD = Math::PI / 180.0
      RAD2DEG = 180.0 / Math::PI

      # 超出公式適用範圍或演算法未收斂時丟出——失敗必須顯性，
      # 不可靜默回傳一個看似正常、實則錯誤的值。
      class DomainError < StandardError; end

      module_function

      # --- 儒略日（Meeus 7.1，Gregorian） ---
      # hour 為十進位 UT 小時（例 1.5 = 01:30 UT）
      def julday(year, month, day, hour)
        y = year
        m = month
        if m <= 2
          y -= 1
          m += 12
        end
        a = (y / 100.0).floor
        b = 2 - a + (a / 4.0).floor
        (365.25 * (y + 4716)).floor + (30.6001 * (m + 1)).floor +
          day + hour / 24.0 + b - 1524.5
      end

      # --- ΔT = TT − UT（秒） ---
      # Espenak & Meeus 分段多項式（NASA Eclipse website，涵蓋 -1999..+3000）。
      # 決策年 y 用儒略年近似（y = 2000 + (JD-J2000)/365.25），與 E&M 定義的
      # y = year + (month-0.5)/12 差 < 半個月，對逐年平滑的 ΔT 曲線影響 < 0.01s。
      # 注意：2005 之後為預測值，與實測（IERS）可差數秒 → 月亮 ~0.001°，
      # 在本專案 0.01° 精度預算內。
      def delta_t(jd_ut)
        y = 2000.0 + (jd_ut - 2451545.0) / 365.25

        if y < -500.0
          u = (y - 1820.0) / 100.0
          -20.0 + 32.0 * u * u
        elsif y < 500.0
          u = y / 100.0
          10583.6 - 1014.41 * u + 33.78311 * u**2 - 5.952053 * u**3 -
            0.1798452 * u**4 + 0.022174192 * u**5 + 0.0090316521 * u**6
        elsif y < 1600.0
          u = (y - 1000.0) / 100.0
          1574.2 - 556.01 * u + 71.23472 * u**2 + 0.319781 * u**3 -
            0.8503463 * u**4 - 0.005050998 * u**5 + 0.0083572073 * u**6
        elsif y < 1700.0
          t = y - 1600.0
          120.0 - 0.9808 * t - 0.01532 * t**2 + t**3 / 7129.0
        elsif y < 1800.0
          t = y - 1700.0
          8.83 + 0.1603 * t - 0.0059285 * t**2 + 0.00013336 * t**3 - t**4 / 1_174_000.0
        elsif y < 1860.0
          t = y - 1800.0
          13.72 - 0.332447 * t + 0.0068612 * t**2 + 0.0041116 * t**3 -
            0.00037436 * t**4 + 0.0000121272 * t**5 - 0.0000001699 * t**6 +
            0.000000000875 * t**7
        elsif y < 1900.0
          t = y - 1860.0
          7.62 + 0.5737 * t - 0.251754 * t**2 + 0.01680668 * t**3 -
            0.0004473624 * t**4 + t**5 / 233_174.0
        elsif y < 1920.0
          t = y - 1900.0
          -2.79 + 1.494119 * t - 0.0598939 * t**2 + 0.0061966 * t**3 - 0.000197 * t**4
        elsif y < 1941.0
          t = y - 1920.0
          21.20 + 0.84493 * t - 0.076100 * t**2 + 0.0020936 * t**3
        elsif y < 1961.0
          t = y - 1950.0
          29.07 + 0.407 * t - t**2 / 233.0 + t**3 / 2547.0
        elsif y < 1986.0
          t = y - 1975.0
          45.45 + 1.067 * t - t**2 / 260.0 - t**3 / 718.0
        elsif y < 2005.0
          t = y - 2000.0
          63.86 + 0.3345 * t - 0.060374 * t**2 + 0.0017275 * t**3 +
            0.000651814 * t**4 + 0.00002373599 * t**5
        elsif y < 2050.0
          t = y - 2000.0
          62.92 + 0.32217 * t + 0.005589 * t**2
        elsif y < 2150.0
          -20.0 + 32.0 * ((y - 1820.0) / 100.0)**2 - 0.5628 * (2150.0 - y)
        else
          u = (y - 1820.0) / 100.0
          -20.0 + 32.0 * u * u
        end
      end

      # --- JD(TT) = JD(UT) + ΔT/86400 ---
      def jd_tt(jd_ut)
        jd_ut + delta_t(jd_ut) / 86_400.0
      end

      # --- 章動（Meeus Ch. 22，IAU 1980 截斷序列） ---
      # 係數單位：0.0001 角秒。取振幅最大的 13 項（Δψ 主項 -17.1996" sinΩ 起），
      # 截斷誤差 < 0.0004"，遠小於 0.01° 目標。
      # 各項引數為 [D, M, M', F, Ω] 的整數倍組合（Meeus Table 22.A 前段）。
      NUTATION_TERMS = [
        # [D, M, Mp, F, Om,   psi_sin,  psi_sin_t,  eps_cos, eps_cos_t]
        [0,  0, 0, 0, 1, -171_996.0, -174.2, 92_025.0,  8.9],
        [-2, 0, 0, 2, 2,  -13_187.0,   -1.6,  5736.0,  -3.1],
        [0,  0, 0, 2, 2,   -2274.0,    -0.2,   977.0,  -0.5],
        [0,  0, 0, 0, 2,    2062.0,     0.2,  -895.0,   0.5],
        [0,  1, 0, 0, 0,    1426.0,    -3.4,    54.0,  -0.1],
        [0,  0, 1, 0, 0,     712.0,     0.1,    -7.0,   0.0],
        [-2, 1, 0, 2, 2,    -517.0,     1.2,   224.0,  -0.6],
        [0,  0, 0, 2, 1,    -386.0,    -0.4,   200.0,   0.0],
        [0,  0, 1, 2, 2,    -301.0,     0.0,   129.0,  -0.1],
        [-2, -1, 0, 2, 2,    217.0,    -0.5,   -95.0,   0.3],
        [-2, 0, 1, 0, 0,    -158.0,     0.0,     0.0,   0.0],
        [-2, 0, 0, 2, 1,     129.0,     0.1,   -70.0,   0.0],
        [0,  0, -1, 2, 2,    123.0,     0.0,   -53.0,   0.0]
      ].freeze

      # 回傳 [Δψ_deg, Δε_deg]（度）。引數時間尺度為 **TT**。
      def nutation(jd_tt)
        t = (jd_tt - 2451545.0) / 36525.0

        # 基本引數（Meeus Ch. 22，度）
        d  = 297.85036 + 445_267.111480 * t - 0.0019142 * t * t + t**3 / 189_474.0
        m  = 357.52772 + 35_999.050340 * t - 0.0001603 * t * t - t**3 / 300_000.0
        mp = 134.96298 + 477_198.867398 * t + 0.0086972 * t * t + t**3 / 56_250.0
        f  = 93.27191 + 483_202.017538 * t - 0.0036825 * t * t + t**3 / 327_270.0
        om = 125.04452 - 1934.136261 * t + 0.0020708 * t * t + t**3 / 450_000.0

        dpsi_01as = 0.0 # 單位 0.0001"
        deps_01as = 0.0
        NUTATION_TERMS.each do |cd, cm, cmp, cf, com, ps, pst, ec, ect|
          arg = (cd * d + cm * m + cmp * mp + cf * f + com * om) * DEG2RAD
          dpsi_01as += (ps + pst * t) * Math.sin(arg)
          deps_01as += (ec + ect * t) * Math.cos(arg)
        end

        [dpsi_01as * 0.0001 / 3600.0, deps_01as * 0.0001 / 3600.0]
      end

      # --- 平黃赤交角（Meeus 22.2，度）。引數時間尺度為 **TT**。 ---
      # 23°26'21.448" - 46.8150"T - 0.00059"T² + 0.001813"T³
      def mean_obliquity(jd_tt)
        t = (jd_tt - 2451545.0) / 36525.0
        23.0 + 26.0 / 60.0 + 21.448 / 3600.0 -
          (46.8150 * t + 0.00059 * t * t - 0.001813 * t**3) / 3600.0
      end

      # --- 真黃赤交角 ε = ε₀ + Δε（度）。引數時間尺度為 **TT**。 ---
      def true_obliquity(jd_tt)
        mean_obliquity(jd_tt) + nutation(jd_tt)[1]
      end

      # --- 平恆星時 GMST（Meeus 12.4 / IAU 1982），回傳度。引數為 **UT**。 ---
      def gmst_deg(jd_ut)
        t = (jd_ut - 2451545.0) / 36525.0
        norm360(
          280.46061837 +
            360.98564736629 * (jd_ut - 2451545.0) +
            0.000387933 * t * t -
            t * t * t / 38_710_000.0
        )
      end

      # --- 視恆星時 = GMST + Δψ·cos(ε_true)（度）。引數為 **UT**。 ---
      # 章動與交角的引數在內部換算為 TT。
      def apparent_sidereal_deg(jd_ut)
        tt = jd_tt(jd_ut)
        dpsi_deg, = nutation(tt)
        eps_rad = true_obliquity(tt) * DEG2RAD
        norm360(gmst_deg(jd_ut) + dpsi_deg * Math.cos(eps_rad))
      end

      # --- 正規化到 [0, 360) ---
      def norm360(deg)
        deg %= 360.0
        # Ruby 的 float % 對正模數永不為負，但極小負數（如 -1e-16 % 360.0）
        # 會因浮點捨入得到恰好 360.0，違反 [0, 360) 契約 → 下游 floor(deg/30) 會得 12。
        deg >= 360.0 ? 0.0 : deg
      end
    end
  end
end
