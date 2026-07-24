# frozen_string_literal: true

require_relative "core"

module AstroChart
  module Pure
    # Houses — MIT-safe 純 Ruby Placidus 宮位（ASC / MC / 12 宮頭）。
    #
    # 零外部依賴、不參考 Swiss Ephemeris C 原始碼，僅使用公開文獻公式：
    #   - 視恆星時 / 章動 / 黃赤交角：見 Core（Meeus Ch. 12 / 22）
    #   - ASC / MC：標準球面天文公式（Meeus Ch. 13 座標轉換推得）
    #   - Placidus 宮頭：古典半弧迭代法（半日弧 SA = arccos(-tanφ·tanδ)，
    #     宮頭 11/12 位於 RAMC 東側 1/3、2/3 半日弧處；宮頭 2/3 以半夜弧對應）
    #
    # 公開 API：
    #   Houses.calc(jd_ut, lat, lon)
    #     -> { "cusps" => [12 floats], "ascendant" => Float, "mc" => Float }
    #     欄位與 AstroChart::Ext.houses(jd, lat, lon, "P".ord) 相同。
    #
    # 適用範圍：|lat| < ~66°（Placidus 在極圈內無定義）。
    # 超出範圍或迭代未收斂時 raise Core::DomainError（顯性失敗，不靜默 clamp）。
    module Houses
      DEG2RAD = Core::DEG2RAD
      RAD2DEG = Core::RAD2DEG

      module_function

      # jd_ut: UT 儒略日；lat: 地理緯度（北正）；lon: 地理經度（東正）
      def calc(jd_ut, lat, lon)
        tt = Core.jd_tt(jd_ut)
        eps = Core.true_obliquity(tt) * DEG2RAD          # 真黃赤交角（弧度）
        ast_deg = Core.apparent_sidereal_deg(jd_ut)      # 視恆星時（度）
        armc = Core.norm360(ast_deg + lon)               # 天頂赤經 RAMC

        phi = lat * DEG2RAD
        mc  = mc_longitude(armc, eps)
        asc = asc_longitude(armc, eps, phi)

        # Placidus 半弧迭代：宮頭 11、12（地平上，RAMC 東側）與 2、3（地平下）
        c11 = placidus_cusp(armc, eps, phi, 30.0,  1.0 / 3.0, :diurnal)
        c12 = placidus_cusp(armc, eps, phi, 60.0,  2.0 / 3.0, :diurnal)
        c2  = placidus_cusp(armc, eps, phi, 120.0, 2.0 / 3.0, :nocturnal)
        c3  = placidus_cusp(armc, eps, phi, 150.0, 1.0 / 3.0, :nocturnal)

        cusps = Array.new(12)
        cusps[0]  = asc                        # 第 1 宮 = ASC
        cusps[1]  = c2
        cusps[2]  = c3
        cusps[3]  = Core.norm360(mc + 180.0)   # 第 4 宮 = MC 對沖
        cusps[4]  = Core.norm360(c11 + 180.0)
        cusps[5]  = Core.norm360(c12 + 180.0)
        cusps[6]  = Core.norm360(asc + 180.0)  # 第 7 宮 = ASC 對沖
        cusps[7]  = Core.norm360(c2 + 180.0)
        cusps[8]  = Core.norm360(c3 + 180.0)
        cusps[9]  = mc                         # 第 10 宮 = MC
        cusps[10] = c11
        cusps[11] = c12

        { "cusps" => cusps, "ascendant" => asc, "mc" => mc }
      end

      # --- MC：天頂赤經 → 黃道經度 ---
      # tan λ_MC = tan(ARMC) / cos ε，以 atan2 處理象限
      def mc_longitude(armc_deg, eps)
        ra = armc_deg * DEG2RAD
        Core.norm360(Math.atan2(Math.sin(ra), Math.cos(ra) * Math.cos(eps)) * RAD2DEG)
      end

      # --- ASC：標準公式 ---
      # λ_ASC = atan2( cos ARMC, -(sin ARMC · cos ε + tan φ · sin ε) )
      def asc_longitude(armc_deg, eps, phi)
        ra = armc_deg * DEG2RAD
        Core.norm360(
          Math.atan2(
            Math.cos(ra),
            -(Math.sin(ra) * Math.cos(eps) + Math.tan(phi) * Math.sin(eps))
          ) * RAD2DEG
        )
      end

      # --- Placidus 宮頭半弧迭代 ---
      # 定義：黃道上一點 (α, δ)，半日弧 SA_d = arccos(-tanφ·tanδ)、半夜弧 SA_n = arccos(tanφ·tanδ)。
      #   宮頭 11：α = RAMC + (1/3)·SA_d      宮頭 12：α = RAMC + (2/3)·SA_d
      #   宮頭 2 ：α = RAMC + 180 - (2/3)·SA_n 宮頭 3 ：α = RAMC + 180 - (1/3)·SA_n
      # 黃道點的赤緯由 tan δ = tan ε · sin α 得出，固定點迭代至收斂。
      # offset_deg：初值偏移（赤道情形的精確解）；frac：半弧比例；mode：地平上/下。
      def placidus_cusp(armc_deg, eps, phi, offset_deg, frac, mode)
        tan_phi = Math.tan(phi)
        tan_eps = Math.tan(eps)
        ra = (armc_deg + offset_deg) * DEG2RAD
        armc_rad = armc_deg * DEG2RAD

        converged = false
        60.times do
          dec = Math.atan(tan_eps * Math.sin(ra)) # 黃道點赤緯
          x = tan_phi * Math.tan(dec)
          if x.abs > 1.0
            # 極圈內該點無升落，Placidus 無定義。顯性失敗，不靜默 clamp。
            raise Core::DomainError,
                  "Placidus 在此緯度無定義（|tanφ·tanδ| = #{x.abs.round(4)} > 1，lat=#{(phi * RAD2DEG).round(4)}°）"
          end
          new_ra =
            if mode == :diurnal
              armc_rad + frac * Math.acos(-x)
            else
              armc_rad + Math::PI - frac * Math.acos(x)
            end
          step = (new_ra - ra).abs
          ra = new_ra # 先採納本次結果，收斂時回傳的才是最終值
          if step < 1e-9 * DEG2RAD
            converged = true
            break
          end
        end
        raise Core::DomainError, "Placidus 宮頭迭代 60 次未收斂" unless converged

        # 赤經 → 黃道經度：tan λ = tan α / cos ε
        Core.norm360(Math.atan2(Math.sin(ra), Math.cos(ra) * Math.cos(eps)) * RAD2DEG)
      end
    end
  end
end
