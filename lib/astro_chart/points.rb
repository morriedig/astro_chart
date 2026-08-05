# frozen_string_literal: true

require_relative "houses"

module AstroChart
  # Derived chart points that are not physical bodies:
  # 福點 (Part of Fortune) and 莉莉絲 (mean Black Moon Lilith / mean lunar apogee).
  module Points
    # Part of Fortune (福點), ecliptic longitude in degrees 0-360.
    #
    # Day chart:   ASC + Moon - Sun
    # Night chart: ASC - Moon + Sun
    def self.fortune(asc:, sun:, moon:, day_chart:)
      longitude = day_chart ? asc + moon - sun : asc - moon + sun
      longitude % 360.0
    end

    # Whether the chart is a day birth: the Sun is above the horizon,
    # i.e. the Sun falls in houses 7-12 for the given house cusps.
    # Returns nil when the Sun cannot be placed (nil/empty inputs).
    #
    # Note: this matches the horizon only for quadrant systems whose cusp 1
    # is the ascendant (e.g. Placidus). For sect determination independent
    # of the display house system, use .day_chart_from_horizon? instead.
    def self.day_chart?(sun_longitude, cusps)
      house = Houses.find_house(sun_longitude, cusps)
      return nil if house.nil?

      house >= 7
    end

    # Whether the chart is a day birth, judged directly from the horizon
    # (ASC–DSC axis): the Sun is above the horizon when its ecliptic
    # longitude lies in the half-circle from the descendant (ASC + 180°)
    # forward to the ascendant — equivalent to quadrant houses 7-12.
    # Sect is an astronomical fact, so this is independent of the display
    # house system. Returns nil when either input is missing.
    def self.day_chart_from_horizon?(sun_longitude, ascendant)
      return nil if sun_longitude.nil? || ascendant.nil?

      ((sun_longitude - ascendant) % 360.0) >= 180.0
    end

    # Antiscion (映點): the reflection of an ecliptic longitude across the
    # Cancer–Capricorn solstice axis (0° 巨蟹 / 0° 摩羯). Two points are in
    # antiscia when they are equidistant from that axis and thus receive the
    # same amount of daylight; classically read as a hidden conjunction.
    #
    #   antiscion = (180 − L) mod 360
    #
    # e.g. 15° 牡羊 (L=15) → 15° 處女 (165); a point on the axis maps to itself.
    def self.antiscion(longitude)
      (180.0 - longitude) % 360.0
    end

    # Contra-antiscion (反映點): reflection across the Aries–Libra equinox
    # axis (0° 牡羊 / 0° 天秤) — the antiscion's opposite point.
    #
    #   contra_antiscion = (360 − L) mod 360
    def self.contra_antiscion(longitude)
      (360.0 - longitude) % 360.0
    end

    # Mean Black Moon Lilith (莉莉絲): ecliptic longitude of the mean lunar
    # apogee, degrees 0-360, for a given Julian Day (UT).
    #
    # Uses the mean longitude of the lunar perigee polynomial (Meeus,
    # "Astronomical Algorithms", mean elements of the lunar orbit) + 180°.
    # T is measured in Julian centuries from J2000.0. The TT-UT difference
    # is ignored: the apogee moves ~0.111°/day, so delta-T contributes well
    # under 0.001° in 1900-2100.
    def self.lilith(jd)
      t = (jd - 2451545.0) / 36525.0
      perigee = 83.3532465 +
                4069.0137287 * t -
                0.0103200 * t**2 -
                t**3 / 80_053.0 +
                t**4 / 18_999_000.0
      (perigee + 180.0) % 360.0
    end
  end
end
