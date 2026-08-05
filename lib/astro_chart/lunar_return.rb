require_relative "ephemeris"
require_relative "solar_return"

module AstroChart
  # Lunar return chart (月亮回歸盤): the chart cast for the exact UTC instant the
  # transiting Moon returns to its natal longitude — a monthly (~27.32-day)
  # cycle, the lunar analogue of the solar return.
  #
  #   natal  = AstroChart::Chart.new(...).generate
  #   result = AstroChart::LunarReturn.for_date(natal, "2026-07-24")
  #   result["return_jd"]       # Julian Day (UT) of the nearest return
  #   result["return_time_utc"] # ISO8601 UTC
  #   result["chart"]           # full chart at the return instant
  #
  # The instant is found by Newton iteration on the Moon's longitude starting
  # from the target date, so it converges to the return nearest that date
  # (within ~±½ cycle). Chart building and JD↔UTC reuse SolarReturn.
  module LunarReturn
    MOON_ID = Ephemeris::PLANETS["月亮"]

    class ConvergenceError < StandardError; end

    CONVERGENCE_DEG = 1e-4
    MAX_ITERATIONS  = 40 # more than the Sun: the Moon's speed varies ~11-15°/day

    # natal_chart: a Chart#generate result hash. target_date: "YYYY-MM-DD" —
    # the returned instant is the lunar return nearest this date.
    # Location defaults to the natal coordinates; pass latitude:/longitude:
    # (and timezone:, informational) to relocate.
    def self.for_date(natal_chart, target_date, latitude: nil, longitude: nil, timezone: nil)
      natal_moon = natal_moon_degree(natal_chart)

      input = natal_chart["input"] || {}
      coords = input["coordinates"] || {}
      lat = (latitude || coords["latitude"])
      lng = (longitude || coords["longitude"])
      tz  = (timezone || input["timezone"])
      if lat.nil? || lng.nil?
        raise ArgumentError, "no coordinates: natal chart input has none and none were given"
      end

      jd = find_return_jd(natal_moon, target_date)

      {
        "return_jd"       => jd,
        "return_time_utc" => SolarReturn.jd_to_utc_iso8601(jd),
        "location"        => { "latitude" => lat.to_f, "longitude" => lng.to_f, "timezone" => tz },
        "chart"           => SolarReturn.build_chart_at(jd, lat.to_f, lng.to_f),
      }
    end

    # Newton iteration on the Moon's longitude from the target date.
    def self.find_return_jd(target_deg, target_date)
      y, m, d = target_date.split("-").map(&:to_i)
      raise ArgumentError, "invalid date: #{target_date.inspect}" if y.nil? || m.nil? || d.nil?

      jd = Ephemeris.julday(y, m, d, 0.0)

      MAX_ITERATIONS.times do
        delta = SolarReturn.angle_delta(target_deg - Ephemeris.calc_ut(jd, MOON_ID))
        return jd if delta.abs < CONVERGENCE_DEG

        jd += delta / moon_speed(jd)
      end

      raise ConvergenceError,
            "lunar return did not converge within #{MAX_ITERATIONS} iterations " \
            "(date=#{target_date}, target=#{target_deg})"
    end

    # Moon's longitudinal speed (deg/day) via central difference (~13.2).
    def self.moon_speed(jd, step = 0.02)
      SolarReturn.angle_delta(
        Ephemeris.calc_ut(jd + step, MOON_ID) - Ephemeris.calc_ut(jd - step, MOON_ID)
      ) / (2.0 * step)
    end

    def self.natal_moon_degree(chart)
      planets = chart&.dig("chart", "planets")
      raise ArgumentError, "chart has no planets data" if planets.nil? || planets.empty?

      moon = planets.find { |p| p["planet"] == "月亮" }
      raise ArgumentError, "chart has no 月亮 position" if moon.nil? || moon["total_degree"].nil?

      moon["total_degree"]
    end

    private_class_method :natal_moon_degree
  end
end
