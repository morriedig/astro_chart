# frozen_string_literal: true

module AstroChart
  DEFAULT_BACKEND = :pure

  # Backend selection lives on Ephemeris (not the AstroChart top-level
  # constant) so host apps that reassign or remove the AstroChart constant
  # (e.g. a Rails app whose ActiveRecord model claims the name after
  # capturing the gem classes) never break internal dispatch.
  # AstroChart.backend / backend= below stay as thin delegators for
  # API compatibility.
  class << self
    # Current ephemeris backend (:pure or :swiss). Defaults to :pure.
    def backend
      Ephemeris.backend
    end

    # Switch the ephemeris backend.
    #
    #   AstroChart.backend = :pure   # pure-Ruby (default, no C extension needed)
    #   AstroChart.backend = :swiss  # Swiss Ephemeris C extension (AGPL)
    def backend=(name)
      Ephemeris.backend = name
    end

    def load_swiss_extension!
      Ephemeris.load_swiss_extension!
    end
  end

  # Backend-agnostic ephemeris facade. All public callers go through this
  # module so the backend (:pure / :swiss) can be swapped without touching
  # the rest of the code.
  module Ephemeris
    class << self
      # Current ephemeris backend (:pure or :swiss). Defaults to :pure.
      def backend
        @backend ||= DEFAULT_BACKEND
      end

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
        return if defined?(Ext)

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
      case backend
      when :swiss then Ext.julday(year, month, day, hour)
      else Pure.julday(year, month, day, hour)
      end
    end

    # Calculate planet apparent ecliptic longitude (degrees 0-360).
    def self.calc_ut(jd, planet_id)
      case backend
      when :swiss then Ext.calc_ut(jd, planet_id)
      else Pure.calc_ut(jd, planet_id)
      end
    end

    # Apparent geocentric ecliptic [longitude, latitude] in degrees. Pure
    # backend only (the Swiss extension exposes latitude via its own API).
    def self.ecliptic_latlon(jd, planet_id)
      Pure.ecliptic_latlon(jd, planet_id)
    end

    # Apparent daily motion in ecliptic longitude (degrees/day), via central
    # difference of calc_ut at jd ± 0.5 day. The difference is folded into
    # (-180, 180] so the 0°/360° wraparound never produces a spurious value.
    # Negative speed = retrograde motion.
    #
    # When jd ± 0.5 falls outside a body's valid ephemeris window (e.g. the
    # pure Pluto series' 1885-2099 range) while jd itself is inside, the
    # stencil falls back to a one-sided difference over half a day, so
    # charts at the very edges of the documented range still work. A jd
    # that is itself out of range still raises Pure::Core::DomainError.
    def self.speed(jd, planet_id)
      a, b, days =
        begin
          [calc_ut(jd - 0.5, planet_id), calc_ut(jd + 0.5, planet_id), 1.0]
        rescue Pure::Core::DomainError
          begin
            [calc_ut(jd, planet_id), calc_ut(jd + 0.5, planet_id), 0.5]
          rescue Pure::Core::DomainError
            [calc_ut(jd - 0.5, planet_id), calc_ut(jd, planet_id), 0.5]
          end
        end
      (((b - a + 540.0) % 360.0) - 180.0) / days
    end

    # Whether the body is retrograde (moving backwards in longitude) at jd.
    def self.retrograde?(jd, planet_id)
      speed(jd, planet_id) < 0
    end

    # Calculate house cusps + ascendant.
    # Returns { "cusps" => [12 floats], "ascendant" => float, "mc" => float }
    def self.houses(jd, latitude, longitude, system = "P")
      case backend
      when :swiss then Ext.houses(jd, latitude, longitude, system.ord)
      else Pure.houses(jd, latitude, longitude, system)
      end
    end
  end
end
