require_relative "ephemeris"
require_relative "pure/core"

module AstroChart
  # Astrocartography (星象地圖 / relocational lines).
  #
  # For a fixed birth instant, every body is angular (on the horizon or the
  # meridian) along particular curves across the globe. We return, per body,
  # four lines in geographic coordinates (longitude east-positive, −180..180):
  #
  #   MC  — the body culminates on the upper meridian (a vertical meridian).
  #   IC  — the body is on the lower meridian (a vertical meridian).
  #   ASC — the body rises on the eastern horizon (a curve of latitude points).
  #   DSC — the body sets on the western horizon (a curve of latitude points).
  #
  # Method (Meeus, positional astronomy): from the body's apparent ecliptic
  # longitude λ and the true obliquity ε we form its equatorial coordinates
  # (RA α, Dec δ); with the Greenwich apparent sidereal time (GST):
  #   MC longitude  = α − GST
  #   IC longitude  = α − GST + 180°
  # and at latitude φ the body is on the horizon when its hour angle is
  #   H = ±arccos(−tanφ·tanδ)   (no solution ⇒ circumpolar, the line ends),
  # rising at H = −H0 (eastern), setting at H = +H0 (western), giving
  #   longitude = α + H − GST.
  #
  # RA/Dec use each body's true apparent ecliptic latitude (via
  # Ephemeris.ecliptic_latlon), so the lines are accurate for the high-latitude
  # bodies (Moon, Pluto) too — not just longitude-only approximations.
  module Astrocartography
    Core = Pure::Core
    DEG2RAD = Core::DEG2RAD
    RAD2DEG = Core::RAD2DEG

    # The ten bodies conventionally mapped.
    BODIES = ["太陽", "月亮", "水星", "金星", "火星", "木星",
              "土星", "天王星", "海王星", "冥王星"].freeze

    # Latitude span and step for the rising/setting curves (degrees).
    LAT_MIN = -75
    LAT_MAX = 75
    LAT_STEP = 1

    module_function

    # jd_ut: birth Julian Day (UT).
    # Returns Array of:
    #   { "planet" => "太陽",
    #     "mc" => <lon>, "ic" => <lon>,            # single geographic longitudes
    #     "asc" => [ [ [lat,lon], ... ], ... ],    # rising curve, as segments
    #     "dsc" => [ [ [lat,lon], ... ], ... ] }   # setting curve, as segments
    def lines(jd_ut)
      gst = Core.apparent_sidereal_deg(jd_ut)
      eps = Core.true_obliquity(Core.jd_tt(jd_ut)) * DEG2RAD

      BODIES.map do |name|
        lam_deg, beta_deg = Ephemeris.ecliptic_latlon(jd_ut, Ephemeris::PLANETS[name])
        lam = lam_deg * DEG2RAD
        beta = beta_deg * DEG2RAD
        # RA/Dec from apparent ecliptic longitude, latitude and obliquity
        # (Meeus, Astronomical Algorithms, eqs. 13.3–13.4).
        ra = Core.norm360(Math.atan2(
          Math.sin(lam) * Math.cos(eps) - Math.tan(beta) * Math.sin(eps),
          Math.cos(lam)
        ) * RAD2DEG)
        dec = Math.asin(Math.sin(beta) * Math.cos(eps) + Math.cos(beta) * Math.sin(eps) * Math.sin(lam))

        {
          "planet" => name,
          "mc"     => norm180(ra - gst),
          "ic"     => norm180(ra - gst + 180.0),
          "asc"    => horizon_curve(ra, dec, gst, :rising),
          "dsc"    => horizon_curve(ra, dec, gst, :setting),
        }
      end
    end

    # Segments of [lat, lon] points where the body is on the eastern (rising)
    # or western (setting) horizon. A circumpolar latitude breaks the curve, so
    # the result is an array of contiguous segments (each a polyline).
    def horizon_curve(ra_deg, dec_rad, gst, mode)
      tan_dec = Math.tan(dec_rad)
      segments = []
      current = []
      lat = LAT_MIN.to_f
      while lat <= LAT_MAX
        x = -Math.tan(lat * DEG2RAD) * tan_dec
        if x.abs <= 1.0
          h0 = Math.acos(x) * RAD2DEG
          hour = mode == :rising ? -h0 : h0
          current << [lat.round(2), norm180(ra_deg + hour - gst)]
        elsif !current.empty?
          segments << current
          current = []
        end
        lat += LAT_STEP
      end
      segments << current unless current.empty?
      segments
    end

    # Normalize degrees to (−180, 180].
    def norm180(deg)
      d = Core.norm360(deg)
      d > 180.0 ? d - 360.0 : d
    end

    private_class_method :horizon_curve, :norm180
  end
end
