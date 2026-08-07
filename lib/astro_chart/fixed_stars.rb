require_relative "ephemeris"
require_relative "pure/core"
require_relative "pure/fixed_stars_data"

module AstroChart
  # Fixed stars (恆星): the ecliptic longitude of each catalogued star at a birth
  # instant, and its conjunctions to the chart's bodies.
  #
  # Pipeline (Meeus, Astronomical Algorithms 2nd ed.): the star's J2000/ICRS
  # equatorial position (from Swiss Ephemeris sefstars.txt) is advanced by proper
  # motion to the epoch, precessed J2000→date by the rigorous ζ/z/θ rotation
  # (Ch. 21), then rotated to the ecliptic of date with the true obliquity
  # (Ch. 13). Nutation and aberration are arc-second scale and skipped — far
  # inside any fixed-star conjunction orb.
  #
  # Traditional nature/keyword are editorial (Robson, 1923), not astrometry.
  module FixedStars
    Core = Pure::Core
    DEG2RAD = Core::DEG2RAD
    RAD2DEG = Core::RAD2DEG
    STARS = Pure::FixedStarsData::STARS

    # Fixed-star conjunctions are read tight; 1° is the common working orb.
    DEFAULT_ORB = 1.0

    module_function

    # Ecliptic longitude (degrees, 0-360) of one catalogue star at jd_ut.
    def ecliptic_longitude(star, jd_ut)
      jd_tt = Core.jd_tt(jd_ut)
      t = (jd_tt - 2_451_545.0) / 36_525.0 # Julian centuries from J2000
      ty = (jd_tt - 2_451_545.0) / 365.25  # Julian years from J2000

      # 1) Proper motion (mas/yr → deg). pm_ra is μα·cosδ, so divide out cosδ₀.
      dec0 = star[:dec]
      mu_alpha = (star[:pm_ra] / 3_600_000.0) / Math.cos(dec0 * DEG2RAD)
      alpha = Core.norm360(star[:ra] + mu_alpha * ty) * DEG2RAD
      delta = (dec0 + (star[:pm_dec] / 3_600_000.0) * ty) * DEG2RAD

      # 2) Precession J2000 → date (Meeus 21.4; starting at J2000 so T=0).
      zeta  = (2306.2181 * t + 0.30188 * t**2 + 0.017998 * t**3) / 3600.0 * DEG2RAD
      z     = (2306.2181 * t + 1.09468 * t**2 + 0.018203 * t**3) / 3600.0 * DEG2RAD
      theta = (2004.3109 * t - 0.42665 * t**2 - 0.041833 * t**3) / 3600.0 * DEG2RAD
      aa = Math.cos(delta) * Math.sin(alpha + zeta)
      bb = Math.cos(theta) * Math.cos(delta) * Math.cos(alpha + zeta) - Math.sin(theta) * Math.sin(delta)
      cc = Math.sin(theta) * Math.cos(delta) * Math.cos(alpha + zeta) + Math.cos(theta) * Math.sin(delta)
      ra_date = Math.atan2(aa, bb) + z
      dec_date = Math.asin(cc)

      # 3) Equatorial (of date) → ecliptic longitude (Meeus 13.1), true obliquity.
      eps = Core.true_obliquity(jd_tt) * DEG2RAD
      lam = Math.atan2(
        Math.sin(ra_date) * Math.cos(eps) + Math.tan(dec_date) * Math.sin(eps),
        Math.cos(ra_date)
      )
      Core.norm360(lam * RAD2DEG)
    end

    # Every star's position at jd_ut:
    #   [ { "star", "nature", "keyword", "vmag", "longitude" }, ... ]
    def positions(jd_ut)
      STARS.map do |s|
        {
          "star"      => s[:name],
          "nature"    => s[:nature],
          "keyword"   => s[:keyword],
          "vmag"      => s[:vmag],
          "longitude" => ecliptic_longitude(s, jd_ut).round(4),
        }
      end
    end

    # Conjunctions between chart bodies and fixed stars, within orb (default 1°).
    #
    # positions: { name => ecliptic_longitude } (e.g. Synastry.positions_from_chart).
    # Returns Array of { "planet", "star", "nature", "keyword", "orb" }, sorted by orb.
    def conjunctions(positions, jd_ut, orb: DEFAULT_ORB)
      star_lons = STARS.map { |s| [s, ecliptic_longitude(s, jd_ut)] }
      results = []
      positions.each do |body, lon|
        star_lons.each do |star, star_lon|
          d = separation(lon, star_lon)
          next if d > orb

          results << {
            "planet"  => body,
            "star"    => star[:name],
            "nature"  => star[:nature],
            "keyword" => star[:keyword],
            "orb"     => d.round(3),
          }
        end
      end
      results.sort_by { |r| r["orb"] }
    end

    # Smallest angular separation (deg) between two ecliptic longitudes.
    def separation(a, b)
      d = (a - b).abs % 360.0
      d > 180.0 ? 360.0 - d : d
    end
  end
end
