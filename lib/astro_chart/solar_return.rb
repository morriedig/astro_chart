module AstroChart
  # Solar return chart (太陽回歸盤): the chart cast for the exact UTC instant
  # the transiting Sun returns to its natal longitude in a given year.
  #
  #   natal  = AstroChart::Chart.new(...).generate
  #   result = SolarReturn.for_year(natal, 2026)
  #   result["return_jd"]       # Julian Day (UT) of the return instant
  #   result["return_time_utc"] # ISO8601 UTC string, e.g. "2026-07-03T05:12:34Z"
  #   result["chart"]           # full chart structure at the return instant
  #
  # The return instant is found by Newton iteration on the Sun's longitude,
  # then the chart is computed directly at that Julian Day (no lossy
  # round-trip through date strings).
  module SolarReturn
    SUN_ID = Ephemeris::PLANETS["太陽"]

    # Raised when the Newton iteration fails to converge (should not happen
    # for the Sun, whose longitude is monotonic at ~0.9856°/day).
    class ConvergenceError < StandardError; end

    # Convergence threshold in degrees (~0.36 arcsec, i.e. under 10 seconds
    # of clock time at the Sun's mean speed).
    CONVERGENCE_DEG = 1e-4
    MAX_ITERATIONS  = 20

    # Same planet => aspect-list wiring as Chart#generate.
    ASPECT_MAP = {
      "太陽"  => "sun_aspects",
      "月亮"  => "moon_aspects",
      "土星"  => "saturn_aspects",
      "金星"  => "venus_aspects",
      "北交點" => "north_node_aspects",
      "南交點" => "south_node_aspects",
    }.freeze

    # Build the solar return for a natal chart (a Chart#generate hash) in the
    # given year. Location defaults to the natal chart's coordinates/timezone;
    # pass latitude:/longitude: (and timezone:, informational) to relocate.
    def self.for_year(natal_chart, year, latitude: nil, longitude: nil, timezone: nil)
      natal_sun = natal_sun_degree(natal_chart)
      month, day = natal_month_day(natal_chart)

      input = natal_chart["input"] || {}
      coords = input["coordinates"] || {}
      lat = latitude  || coords["latitude"]
      lng = longitude || coords["longitude"]
      tz  = timezone  || input["timezone"]
      if lat.nil? || lng.nil?
        raise ArgumentError,
              "no coordinates: natal chart input has none and none were given"
      end
      lat = lat.to_f
      lng = lng.to_f

      jd = find_return_jd(natal_sun, year, month, day)

      {
        "return_jd"       => jd,
        "return_time_utc" => jd_to_utc_iso8601(jd),
        "location"        => {
          "latitude"  => lat,
          "longitude" => lng,
          "timezone"  => tz,
        },
        "chart" => build_chart_at(jd, lat, lng),
      }
    end

    # Newton iteration: find the JD(UT) nearest the birthday in `year` where
    # the Sun's longitude equals target_deg.
    def self.find_return_jd(target_deg, year, month, day)
      jd = Ephemeris.julday(year, month, day, 12.0)

      MAX_ITERATIONS.times do
        delta = angle_delta(target_deg - Ephemeris.calc_ut(jd, SUN_ID))
        return jd if delta.abs < CONVERGENCE_DEG

        jd += delta / sun_speed(jd)
      end

      raise ConvergenceError,
            "solar return did not converge within #{MAX_ITERATIONS} iterations " \
            "(year=#{year}, target=#{target_deg})"
    end

    # Sun's longitudinal speed (deg/day) via central difference (~0.9856).
    def self.sun_speed(jd, step = 0.05)
      diff = angle_delta(
        Ephemeris.calc_ut(jd + step, SUN_ID) - Ephemeris.calc_ut(jd - step, SUN_ID)
      )
      diff / (2.0 * step)
    end

    # Signed shortest angular difference, mapped into [-180, 180).
    def self.angle_delta(deg)
      (deg + 540.0) % 360.0 - 180.0
    end

    # Inverse Julian Day (Meeus, Astronomical Algorithms ch. 7):
    # JD(UT) -> [year, month, day, hour, minute, second] in UTC.
    # Rounded to the nearest whole second before decomposition, so
    # 23:59:59.6 rolls over to 00:00:00 of the next day correctly.
    def self.jd_to_utc(jd)
      total_seconds = ((jd + 0.5) * 86_400.0).round
      z   = total_seconds / 86_400
      sec = total_seconds % 86_400

      if z < 2_299_161 # before the Gregorian reform (1582-10-15)
        a = z
      else
        alpha = ((z - 1_867_216.25) / 36_524.25).floor
        a = z + 1 + alpha - (alpha / 4)
      end

      b = a + 1524
      c = ((b - 122.1) / 365.25).floor
      d = (365.25 * c).floor
      e = ((b - d) / 30.6001).floor

      day   = b - d - (30.6001 * e).floor
      month = e < 14 ? e - 1 : e - 13
      year  = month > 2 ? c - 4716 : c - 4715

      [year, month, day, sec / 3600, (sec % 3600) / 60, sec % 60]
    end

    def self.jd_to_utc_iso8601(jd)
      y, mo, d, h, mi, s = jd_to_utc(jd)
      format("%04d-%02d-%02dT%02d:%02d:%02dZ", y, mo, d, h, mi, s)
    end

    # Chart structure at an exact JD — mirrors the "chart" section of
    # Chart#generate, computed directly with Planets/Houses (Chart itself
    # only accepts date strings, which would lose sub-minute precision).
    def self.build_chart_at(jd, latitude, longitude)
      cusps, ascendant = Houses.calculate(jd, latitude, longitude)

      positions = Planets.calculate_positions(jd)
      planet_details = Planets.build_details(positions, cusps)

      kp = Planets.key_points_data(positions, cusps, ascendant)

      planet_details.each do |planet|
        key = ASPECT_MAP[planet["planet"]]
        planet["aspects"] = kp[key] if key
      end

      planet_details.concat(kp["additional_points"])

      houses_data = cusps.each_with_index.map do |deg, i|
        {
          "house_number" => i + 1,
          "degree"       => deg.round(4),
          "zodiac"       => Zodiac.sign_name(deg),
        }
      end

      {
        "ascendant" => {
          "zodiac"       => Zodiac.sign_name(ascendant),
          "degree"       => (ascendant % 30).round(4),
          "total_degree" => ascendant.round(4),
        },
        "planets" => planet_details,
        "houses"  => houses_data,
      }
    end

    # Natal Sun total longitude from a Chart#generate hash.
    def self.natal_sun_degree(chart)
      planets = chart&.dig("chart", "planets")
      raise ArgumentError, "chart has no planets data" if planets.nil? || planets.empty?

      sun = planets.find { |p| p["planet"] == "太陽" }
      raise ArgumentError, "chart has no 太陽 position" if sun.nil? || sun["total_degree"].nil?

      sun["total_degree"]
    end

    # [month, day] of the natal birthday from a Chart#generate hash.
    def self.natal_month_day(chart)
      birth_date = chart&.dig("input", "birth_date")
      raise ArgumentError, "chart has no input birth_date" if birth_date.nil?

      _, month, day = birth_date.split("-").map(&:to_i)
      raise ArgumentError, "invalid birth_date: #{birth_date.inspect}" if month.nil? || day.nil?

      [month, day]
    end

    private_class_method :natal_sun_degree, :natal_month_day
  end
end
