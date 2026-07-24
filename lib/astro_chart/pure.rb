# frozen_string_literal: true

require_relative "pure/core"
require_relative "pure/houses"
require_relative "pure/vsop87"
require_relative "pure/moon"
require_relative "pure/pluto"

module AstroChart
  # Pure-Ruby ephemeris backend (MIT-safe, zero external dependencies).
  #
  # Front-facing API mirrors the Swiss Ephemeris C extension (AstroChart::Ext):
  #   Pure.julday(year, month, day, hour)      -> JD(UT) Float
  #   Pure.calc_ut(jd_ut, planet_id)           -> apparent ecliptic longitude (deg, 0-360)
  #   Pure.houses(jd_ut, lat, lon, hsys = "P") -> { "cusps" => [12], "ascendant" => f, "mc" => f }
  #
  # planet_id follows the SE convention:
  #   SUN=0 MOON=1 MERCURY=2 VENUS=3 MARS=4 JUPITER=5 SATURN=6
  #   URANUS=7 NEPTUNE=8 PLUTO=9 TRUE_NODE=11
  module Pure
    # planet_id (SE convention) -> handled by which pure module
    VSOP87_PLANET_IDS = [0, 2, 3, 4, 5, 6, 7, 8].freeze
    MOON_ID           = 1
    PLUTO_ID          = 9
    TRUE_NODE_ID      = 11

    module_function

    # Convert calendar date/time (UT) to Julian Day number.
    def julday(year, month, day, hour)
      Core.julday(year, month, day, hour)
    end

    # Apparent ecliptic longitude (degrees, [0, 360)) for the given body.
    def calc_ut(jd_ut, planet_id)
      case planet_id
      when *VSOP87_PLANET_IDS
        Vsop87.apparent_longitude(planet_id, jd_ut)
      when MOON_ID
        Moon.apparent_longitude(jd_ut)
      when PLUTO_ID
        Pluto.apparent_longitude(jd_ut)
      when TRUE_NODE_ID
        Moon.true_node(jd_ut)
      else
        raise ArgumentError,
              "unsupported planet_id #{planet_id.inspect} " \
              "(supported: 0-9 and 11/TRUE_NODE, SE convention)"
      end
    end

    # House cusps + ascendant + MC. Only Placidus is implemented.
    # hsys accepts "P" or 80 ("P".ord) to mirror the C extension's int argument.
    def houses(jd_ut, latitude, longitude, hsys = "P")
      unless hsys == "P" || hsys == 80
        raise ArgumentError,
              "unsupported house system #{hsys.inspect} (pure backend only supports Placidus: \"P\" / 80)"
      end

      Houses.calc(jd_ut, latitude, longitude)
    end
  end
end
