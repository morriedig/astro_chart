# frozen_string_literal: true

module AstroChart
  DEFAULT_BACKEND = :pure

  class << self
    # Current ephemeris backend (:pure or :swiss). Defaults to :pure.
    def backend
      @backend ||= DEFAULT_BACKEND
    end

    # Switch the ephemeris backend.
    #
    #   AstroChart.backend = :pure   # pure-Ruby (default, no C extension needed)
    #   AstroChart.backend = :swiss  # Swiss Ephemeris C extension (AGPL)
    #
    # Selecting :swiss loads the C extension on demand; a missing/uncompiled
    # extension raises LoadError with an explicit message instead of failing
    # silently at call time.
    def backend=(name)
      case name
      when :pure
        @backend = :pure
      when :swiss
        load_swiss_extension!
        @backend = :swiss
      else
        raise ArgumentError,
              "unknown backend #{name.inspect} (expected :pure or :swiss)"
      end
    end

    def load_swiss_extension!
      return if defined?(AstroChart::Ext)

      begin
        require_relative "astro_chart_ext"
      rescue LoadError => e
        raise LoadError,
              "AstroChart :swiss backend requires the compiled Swiss Ephemeris C extension " \
              "(astro_chart_ext). Build it with `rake compile` (or `ruby ext/astro_chart/extconf.rb && make`), " \
              "or use the default pure-Ruby backend (AstroChart.backend = :pure). " \
              "Original error: #{e.message}"
      end
    end
  end

  # Backend-agnostic ephemeris facade. All public callers go through this
  # module so the backend (:pure / :swiss) can be swapped without touching
  # the rest of the code.
  module Ephemeris
    # SE-convention planet ids (numeric literals so the :pure default
    # works without the C extension loaded; values match AstroChart::Ext
    # constants when the extension is present).
    PLANETS = {
      "太陽"   => 0,   # SUN
      "月亮"   => 1,   # MOON
      "水星"   => 2,   # MERCURY
      "金星"   => 3,   # VENUS
      "火星"   => 4,   # MARS
      "木星"   => 5,   # JUPITER
      "土星"   => 6,   # SATURN
      "天王星"  => 7,   # URANUS
      "海王星"  => 8,   # NEPTUNE
      "冥王星"  => 9,   # PLUTO
      "北交點"  => 11,  # TRUE_NODE
    }.freeze

    # Convert date/time to Julian Day number.
    def self.julday(year, month, day, hour)
      case AstroChart.backend
      when :swiss then Ext.julday(year, month, day, hour)
      else Pure.julday(year, month, day, hour)
      end
    end

    # Calculate planet apparent ecliptic longitude (degrees 0-360).
    def self.calc_ut(jd, planet_id)
      case AstroChart.backend
      when :swiss then Ext.calc_ut(jd, planet_id)
      else Pure.calc_ut(jd, planet_id)
      end
    end

    # Calculate house cusps + ascendant.
    # Returns { "cusps" => [12 floats], "ascendant" => float, "mc" => float }
    def self.houses(jd, latitude, longitude, system = "P")
      case AstroChart.backend
      when :swiss then Ext.houses(jd, latitude, longitude, system.ord)
      else Pure.houses(jd, latitude, longitude, system)
      end
    end
  end
end
