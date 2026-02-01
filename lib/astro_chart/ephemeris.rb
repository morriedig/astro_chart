module AstroChart
  # Thin Ruby wrapper around the C extension (AstroChart::Ext).
  # All public callers should go through this module so we can
  # swap the backend without touching the rest of the code.
  module Ephemeris
    PLANETS = {
      "太陽"   => Ext::SUN,
      "月亮"   => Ext::MOON,
      "水星"   => Ext::MERCURY,
      "金星"   => Ext::VENUS,
      "火星"   => Ext::MARS,
      "木星"   => Ext::JUPITER,
      "土星"   => Ext::SATURN,
      "天王星"  => Ext::URANUS,
      "海王星"  => Ext::NEPTUNE,
      "冥王星"  => Ext::PLUTO,
      "北交點"  => Ext::TRUE_NODE,
    }.freeze

    # Convert date/time to Julian Day number.
    def self.julday(year, month, day, hour)
      Ext.julday(year, month, day, hour)
    end

    # Calculate planet ecliptic longitude (degrees 0-360).
    def self.calc_ut(jd, planet_id)
      Ext.calc_ut(jd, planet_id)
    end

    # Calculate house cusps + ascendant.
    # Returns { "cusps" => [12 floats], "ascendant" => float, "mc" => float }
    def self.houses(jd, latitude, longitude, system = "P")
      Ext.houses(jd, latitude, longitude, system.ord)
    end
  end
end
