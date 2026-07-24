# frozen_string_literal: true

require_relative "core"

module AstroChart
  module Pure
    # Pluto — MIT-safe 純 Ruby 冥王星視黃經（零外部依賴）。
    #
    # 只使用公開文獻公式，不參考 Swiss Ephemeris C 原始碼：
    #   - 冥王星日心座標：Jean Meeus, "Astronomical Algorithms" 2nd ed.,
    #     Ch. 37（冥王星專用週期項級數，Table 37.A，適用 1885–2099，
    #     座標基準 = J2000.0 平春分點）
    #   - 地球日心座標：Meeus Ch. 25（太陽幾何黃經 + 半徑向量，
    #     eq. 25.2–25.5，基準 = 當日平春分點；太陽精度 ~0.01°，
    #     冥王星距離 ~31–50 AU，投影到地心方向後誤差稀釋 ~1/31，
    #     對冥王星地心黃經貢獻 < 0.001°）
    #   - 歲差（J2000 → 當日黃道座標）：Meeus Ch. 21（eq. 21.5 的
    #     η/Π/p 起始曆元 J2000 特化式 + eq. 21.7 球面旋轉）
    #   - 光行時 + 光行差：Meeus Ch. 33 — 行星與地球都取 t−τ 時刻
    #     的位置，一次同時涵蓋光行時與（一階）光行差
    #   - 章動 Δψ：Core.nutation（Meeus Ch. 22）
    #
    # 時間尺度：apparent_longitude 吃 **JD(UT)**，內部自換 TT。
    #
    # 公開 API：
    #   Pluto.apparent_longitude(jd_ut) -> 視黃道經度（度，[0,360)，
    #                                      真春分點 of date，含光行時/光行差/章動）
    #   超出 1885–2099 適用範圍 raise Core::DomainError（顯性失敗）。
    module Pluto
      DEG2RAD = Core::DEG2RAD
      RAD2DEG = Core::RAD2DEG

      # Meeus Ch. 37 級數適用範圍 1885–2099（TT）。
      # JD 2409542.5 = 1885-01-01 00:00、JD 2488069.5 = 2100-01-01 00:00。
      JD_TT_MIN = 2409542.5
      JD_TT_MAX = 2488069.5

      # 光行時常數：光走 1 AU 所需天數（Meeus Ch. 33）
      LIGHT_TIME_PER_AU = 0.0057755183

      # Meeus Table 37.A — 43 項週期級數。
      # 每列：[j, s, p, lon_A, lon_B, lat_A, lat_B, rad_A, rad_B]
      #   引數 α = j·J + s·S + p·P（J/S/P 為木星/土星/冥王星平黃經）
      #   longitude/latitude 單位 1e-6 度，radius 單位 1e-7 AU
      #   各量 = Σ (A·sin α + B·cos α)
      TERMS = [
        [0, 0, 1, -19_799_805, 19_850_055, -5_452_852, -14_974_862, 66_865_439, 68_951_812],
        [0, 0, 2,     897_144, -4_954_829,  3_527_812,   1_672_790, -11_827_535,   -332_538],
        [0, 0, 3,     611_149,  1_211_027, -1_050_748,     327_647,   1_593_179, -1_438_890],
        [0, 0, 4,    -341_243,   -189_585,    178_690,    -292_153,     -18_444,    483_220],
        [0, 0, 5,     129_287,    -34_992,     18_650,     100_340,     -65_977,    -85_431],
        [0, 0, 6,     -38_164,     30_893,    -30_697,     -25_823,      31_174,     -6_032],
        [0, 1, -1,     20_442,     -9_987,      4_878,      11_248,      -5_794,     22_161],
        [0, 1, 0,      -4_063,     -5_071,        226,         -64,       4_601,      4_032],
        [0, 1, 1,      -6_016,     -3_336,      2_030,        -836,      -1_729,        234],
        [0, 1, 2,      -3_956,      3_039,         69,        -604,        -415,        702],
        [0, 1, 3,        -667,      3_572,       -247,        -567,         239,        723],
        [0, 2, -2,      1_276,        501,        -57,           1,          67,        -67],
        [0, 2, -1,      1_152,       -917,       -122,         175,       1_034,       -451],
        [0, 2, 0,         630,     -1_277,        -49,        -164,        -129,        504],
        [1, -1, 0,      2_571,       -459,       -197,         199,         480,       -231],
        [1, -1, 1,        899,     -1_449,        -25,         217,           2,       -441],
        [1, 0, -3,     -1_016,      1_043,        589,        -248,      -3_359,        265],
        [1, 0, -2,     -2_343,     -1_012,       -269,         711,       7_856,     -7_832],
        [1, 0, -1,      7_042,        788,        185,         193,          36,     45_763],
        [1, 0, 0,       1_199,       -338,        315,         807,       8_663,      8_547],
        [1, 0, 1,         418,        -67,       -130,         -43,        -809,       -769],
        [1, 0, 2,         120,       -274,          5,           3,         263,       -144],
        [1, 0, 3,         -60,       -159,          2,          17,        -126,         32],
        [1, 0, 4,         -82,        -29,          2,           5,         -35,        -16],
        [1, 1, -3,        -36,        -29,          2,           3,         -19,         -4],
        [1, 1, -2,        -40,          7,          3,           1,         -15,          8],
        [1, 1, -1,        -14,         22,          2,          -1,          -4,         12],
        [1, 1, 0,           4,         13,          1,          -1,           5,          6],
        [1, 1, 1,           5,          2,          0,          -1,           3,          1],
        [1, 1, 3,          -1,          0,          0,           0,           6,         -2],
        [2, 0, -6,          2,          0,          0,          -2,           2,          2],
        [2, 0, -5,         -4,          5,          2,           2,          -2,         -2],
        [2, 0, -4,          4,         -7,         -7,           0,          14,         13],
        [2, 0, -3,         14,         24,         10,          -8,         -63,         13],
        [2, 0, -2,        -49,        -34,         -3,          20,         136,       -236],
        [2, 0, -1,        163,        -48,          6,           5,         273,      1_065],
        [2, 0, 0,           9,        -24,         14,          17,         251,        149],
        [2, 0, 1,          -4,          1,         -2,           0,         -25,         -9],
        [2, 0, 2,          -3,          1,          0,           0,           9,         -2],
        [2, 0, 3,           1,          3,          0,           0,          -8,          7],
        [3, 0, -2,         -3,         -1,          0,           1,           2,        -10],
        [3, 0, -1,          5,         -3,          0,           0,          19,         35],
        [3, 0, 0,           0,          0,          1,           0,          10,          3],
      ].map(&:freeze).freeze

      module_function

      # 冥王星視黃道經度（度，真春分點 of date）。
      # jd_ut: JD(UT)。超出 Meeus Ch. 37 適用範圍（1885–2099）raise DomainError。
      def apparent_longitude(jd_ut)
        jd_tt = Core.jd_tt(jd_ut)
        unless jd_tt >= JD_TT_MIN && jd_tt < JD_TT_MAX
          raise Core::DomainError,
                "Pluto series (Meeus Ch.37) valid only 1885-2099, got JD(TT)=#{jd_tt}"
        end

        # 光行時 + 光行差：行星與地球都取 t−τ 的位置（Meeus Ch. 33）。
        # 地球在 τ 內的位移 = v·τ = v·Δ/c，換成方向偏移正是一階光行差 v/c。
        gx = gy = gz = 0.0
        tau = 0.0
        10.times do |i|
          px, py, pz = pluto_helio_rect(jd_tt - tau, jd_tt)
          ex, ey, ez = earth_helio_rect(jd_tt - tau)
          gx = px - ex
          gy = py - ey
          gz = pz - ez
          delta = Math.sqrt(gx * gx + gy * gy + gz * gz)
          new_tau = LIGHT_TIME_PER_AU * delta
          if (new_tau - tau).abs < 1e-9
            tau = new_tau
            break
          end
          raise Core::DomainError, "Pluto light-time iteration did not converge" if i == 9

          tau = new_tau
        end

        lambda_mean = Math.atan2(gy, gx) * RAD2DEG # 平春分點 of date
        dpsi, = Core.nutation(jd_tt)
        Core.norm360(lambda_mean + dpsi)
      end

      # --- 冥王星日心直角座標（AU，黃道座標，旋轉到 jd_frame_tt 的平春分點） ---
      # Meeus Ch. 37：級數給出 J2000.0 平春分點下的日心 l/b/r，
      # 再用 precess_from_j2000 旋轉到目標曆元。
      def pluto_helio_rect(jd_tt, jd_frame_tt)
        t = (jd_tt - 2_451_545.0) / 36_525.0

        # 木星 / 土星 / 冥王星平黃經（度，Meeus Ch. 37）
        j = 34.35 + 3034.9057 * t
        s = 50.08 + 1222.1138 * t
        p = 238.96 + 144.9600 * t

        sum_l = 0.0
        sum_b = 0.0
        sum_r = 0.0
        TERMS.each do |cj, cs, cp, la, lb, ba, bb, ra, rb|
          alpha = (cj * j + cs * s + cp * p) * DEG2RAD
          sin_a = Math.sin(alpha)
          cos_a = Math.cos(alpha)
          sum_l += la * sin_a + lb * cos_a
          sum_b += ba * sin_a + bb * cos_a
          sum_r += ra * sin_a + rb * cos_a
        end

        l = 238.958116 + 144.96 * t + sum_l * 1e-6 # 度，J2000 平春分點
        b = -3.908239 + sum_b * 1e-6               # 度
        r = 40.7241346 + sum_r * 1e-7              # AU

        l, b = precess_from_j2000(l, b, jd_frame_tt)

        l_rad = l * DEG2RAD
        b_rad = b * DEG2RAD
        cb = Math.cos(b_rad)
        [r * cb * Math.cos(l_rad), r * cb * Math.sin(l_rad), r * Math.sin(b_rad)]
      end

      # --- 地球日心直角座標（AU，當日平春分點黃道座標） ---
      # Meeus Ch. 25（eq. 25.2–25.5）：太陽幾何黃經 ⊙ 與半徑向量 R，
      # 地球日心黃經 = ⊙ + 180°、黃緯 ≈ 0、距離 = R。
      def earth_helio_rect(jd_tt)
        t = (jd_tt - 2_451_545.0) / 36_525.0

        l0 = 280.46646 + 36_000.76983 * t + 0.0003032 * t * t     # 太陽幾何平黃經
        m  = 357.52911 + 35_999.05029 * t - 0.0001537 * t * t     # 太陽平近點角
        e  = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t # 地球軌道離心率

        m_rad = m * DEG2RAD
        c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * Math.sin(m_rad) +
            (0.019993 - 0.000101 * t) * Math.sin(2.0 * m_rad) +
            0.000289 * Math.sin(3.0 * m_rad) # 中心差

        sun_lon = l0 + c            # 太陽真幾何黃經（平春分點 of date）
        nu = m + c                  # 真近點角
        r = 1.000001018 * (1.0 - e * e) / (1.0 + e * Math.cos(nu * DEG2RAD))

        earth_lon_rad = (sun_lon + 180.0) * DEG2RAD
        [r * Math.cos(earth_lon_rad), r * Math.sin(earth_lon_rad), 0.0]
      end

      # --- 黃道座標歲差：J2000.0 → jd_tt 的平春分點（Meeus Ch. 21） ---
      # 起始曆元 = J2000（eq. 21.5 取 T=0）：
      #   η = 47.0029″t − 0.03302″t² + 0.000060″t³
      #   Π = 174°.876384 − 869.8089″t + 0.03536″t²
      #   p = 5029.0966″t + 1.11113″t² − 0.000006″t³
      # 再套 eq. 21.7 球面旋轉。
      def precess_from_j2000(lon_deg, lat_deg, jd_tt)
        t = (jd_tt - 2_451_545.0) / 36_525.0
        return [lon_deg, lat_deg] if t.zero?

        arcsec = 1.0 / 3600.0
        eta = (47.0029 * t - 0.03302 * t * t + 0.000060 * t * t * t) * arcsec
        pi_ = 174.876384 + (-869.8089 * t + 0.03536 * t * t) * arcsec
        pp  = (5029.0966 * t + 1.11113 * t * t - 0.000006 * t * t * t) * arcsec

        eta_rad = eta * DEG2RAD
        lat_rad = lat_deg * DEG2RAD
        pi_lon = (pi_ - lon_deg) * DEG2RAD

        cos_lat = Math.cos(lat_rad)
        sin_lat = Math.sin(lat_rad)
        sin_pl = Math.sin(pi_lon)

        a = Math.cos(eta_rad) * cos_lat * sin_pl - Math.sin(eta_rad) * sin_lat
        b = cos_lat * Math.cos(pi_lon)
        c = Math.sin(eta_rad) * cos_lat * sin_pl + Math.cos(eta_rad) * sin_lat

        new_lon = pp + pi_ - Math.atan2(a, b) * RAD2DEG
        new_lat = Math.asin(c.clamp(-1.0, 1.0)) * RAD2DEG
        [Core.norm360(new_lon), new_lat]
      end
    end
  end
end
