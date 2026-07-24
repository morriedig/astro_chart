# frozen_string_literal: true

require_relative 'core'
require_relative 'vsop87_data'

module AstroChart
  module Pure
    # Vsop87 -- MIT-safe 純 Ruby 太陽 + 行星（水星～海王星）視黃道經度。
    #
    # 只使用公開文獻公式與公開發表資料，不參考 Swiss Ephemeris C 原始碼：
    #   - 行星日心座標：VSOP87D 截斷級數（Bretagnon & Francou 1988,
    #     A&A 202, 309；資料見 vsop87_data.rb）
    #   - 太陽視經度：Jean Meeus, "Astronomical Algorithms" 2nd ed.,
    #     Ch. 25（高精度法：地球日心經度 + 180°、FK5 修正、
    #     光行差 -20.4898"/R、章動 Δψ）
    #   - 行星視經度：Meeus Ch. 33（日心 → 地心，光行時迭代；
    #     地球與行星同取 t-τ 時刻，等效同時涵蓋光行時＋光行差
    #     〔planetary aberration〕），再加章動 Δψ
    #   - VSOP87 動力學分點 → FK5 修正：Meeus eq. 32.3
    #   - 章動 / ΔT / TT 換算：Core（Meeus Ch. 22 / Espenak & Meeus）
    #
    # 公開 API：
    #   Vsop87.apparent_longitude(planet_id, jd_ut) -> 視黃道經度（度, [0,360)）
    #
    # planet_id 採 Swiss Ephemeris 慣例：SUN=0, MERCURY=2, VENUS=3,
    # MARS=4, JUPITER=5, SATURN=6, URANUS=7, NEPTUNE=8。
    # 月亮(1)/冥王星(9)/北交點(11) 不在本模組範圍，傳入會 raise。
    module Vsop87
      DEG2RAD = Core::DEG2RAD
      RAD2DEG = Core::RAD2DEG

      # 光行時常數：光走 1 au 所需天數（Meeus eq. 33.3）
      LIGHT_TIME_DAYS_PER_AU = 0.0057755183

      # planet_id (SE 慣例) => VSOP87 資料 key
      PLANET_KEYS = {
        2 => :mercury,
        3 => :venus,
        4 => :mars,
        5 => :jupiter,
        6 => :saturn,
        7 => :uranus,
        8 => :neptune
      }.freeze

      SUN_ID = 0

      module_function

      # 視黃道經度（apparent geocentric ecliptic longitude，度）。
      # jd_ut 為 JD(UT)；內部經 Core.jd_tt 換算 TT。
      def apparent_longitude(planet_id, jd_ut)
        tt = Core.jd_tt(jd_ut)
        if planet_id == SUN_ID
          sun_apparent_longitude(tt)
        elsif PLANET_KEYS.key?(planet_id)
          planet_apparent_longitude(PLANET_KEYS.fetch(planet_id), tt)
        else
          raise Core::DomainError,
                "Vsop87 不支援 planet_id=#{planet_id}（僅太陽 0 與行星 2..8）"
        end
      end

      # --- 太陽（Meeus Ch. 25 高精度法） ---
      def sun_apparent_longitude(jd_tt)
        l, _b, r = heliocentric_fk5(:earth, jd_tt)
        theta = l * RAD2DEG + 180.0                # 地心幾何經度（FK5）
        theta -= (20.4898 / r) / 3600.0            # 光行差（Meeus 25.10）
        dpsi_deg, = Core.nutation(jd_tt)           # 章動
        Core.norm360(theta + dpsi_deg)
      end

      # --- 行星（Meeus Ch. 33） ---
      # 先以幾何位置求距離 Δ 得光行時 τ，再把「行星與地球」都取 t-τ
      # 重算——兩者同取 t-τ 等效把光行時與（地球速度造成的）光行差
      # 一併涵蓋（planetary aberration；Meeus Ch. 33 註）。τ 迭代兩輪。
      def planet_apparent_longitude(planet_key, jd_tt)
        tau = 0.0
        x = y = 0.0
        2.times do
          ex, ey, ez = heliocentric_rect(:earth, jd_tt - tau)
          px, py, pz = heliocentric_rect(planet_key, jd_tt - tau)
          x = px - ex
          y = py - ey
          z = pz - ez
          delta = Math.sqrt(x * x + y * y + z * z)
          tau = LIGHT_TIME_DAYS_PER_AU * delta
        end
        lambda_deg = Math.atan2(y, x) * RAD2DEG
        dpsi_deg, = Core.nutation(jd_tt)
        Core.norm360(lambda_deg + dpsi_deg)
      end

      # --- 日心黃道直角座標（FK5 修正後；黃道與分點皆為 of date） ---
      def heliocentric_rect(planet_key, jd_tt)
        l, b, r = heliocentric_fk5(planet_key, jd_tt)
        cb = Math.cos(b)
        [r * cb * Math.cos(l), r * cb * Math.sin(l), r * Math.sin(b)]
      end

      # --- 日心球座標 [L_rad, B_rad, R_au]，含 VSOP87→FK5 修正（Meeus 32.3） ---
      def heliocentric_fk5(planet_key, jd_tt)
        l, b, r = heliocentric_raw(planet_key, jd_tt)

        t_cent = (jd_tt - 2_451_545.0) / 36_525.0
        lp = l - (1.397 * t_cent + 0.00031 * t_cent * t_cent) * DEG2RAD
        cos_lp = Math.cos(lp)
        sin_lp = Math.sin(lp)
        dl_arcsec = -0.09033 + 0.03916 * (cos_lp + sin_lp) * Math.tan(b)
        db_arcsec = 0.03916 * (cos_lp - sin_lp)

        [l + dl_arcsec / 3600.0 * DEG2RAD,
         b + db_arcsec / 3600.0 * DEG2RAD,
         r]
      end

      # --- VSOP87D 級數求和 -> [L_rad([0,2π)), B_rad, R_au]（動力學分點） ---
      def heliocentric_raw(planet_key, jd_tt)
        series = Vsop87Data::SERIES.fetch(planet_key) do
          raise Core::DomainError, "無 VSOP87 資料：#{planet_key}"
        end
        t = (jd_tt - 2_451_545.0) / 365_250.0 # Julian millennia (TT)
        l = sum_series(series.fetch(:l), t) % (2.0 * Math::PI)
        l += 2.0 * Math::PI if l.negative?
        b = sum_series(series.fetch(:b), t)
        r = sum_series(series.fetch(:r), t)
        raise Core::DomainError, "VSOP87 R 非正值：#{planet_key} r=#{r}" unless r.positive?

        [l, b, r]
      end

      # orders = [order0_flat, order1_flat, ...]；每個 flat 陣列為連續
      # (A, B, C) 三元組：Σ_k T^k Σ_i A_i cos(B_i + C_i T)
      def sum_series(orders, t)
        total = 0.0
        t_pow = 1.0
        orders.each do |flat|
          sum = 0.0
          i = 0
          n = flat.size
          while i < n
            sum += flat[i] * Math.cos(flat[i + 1] + flat[i + 2] * t)
            i += 3
          end
          total += sum * t_pow
          t_pow *= t
        end
        total
      end
    end
  end
end
