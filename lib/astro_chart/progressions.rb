require_relative "time_conversion"
require_relative "transits"

module AstroChart
  # Secondary progressions (二次推運): "a day for a year".
  #
  # For a target date N years after birth, the progressed chart is the sky
  # N *days* after birth: jd_prog = jd_natal + years_elapsed, where
  # years_elapsed = (jd_target - jd_natal) / 365.2425.
  #
  # Typical usage with a Chart#generate result:
  #
  #   AstroChart::Progressions.secondary(natal_chart, "2026-07-24")
  module Progressions
    # Mean Gregorian year length in days (matches the calendar's 400-year cycle).
    DAYS_PER_YEAR = 365.2425

    # Secondary-progressed positions for a natal chart at a target date.
    #
    # natal_chart: a Chart#generate result hash (its "input" block supplies
    #   birth date/time/timezone, so jd_natal is reconstructed exactly).
    # target_date: "YYYY-MM-DD". The target moment is taken at the same
    #   local birth time + timezone, so whole calendar years elapse cleanly.
    # orb_limit: keep only progressed-to-natal aspects with orb <= limit
    #   (default 1.0 — progressions move slowly, only exact contacts matter).
    #
    # Returns:
    #   {
    #     "progressed_jd" => 2447926.72,
    #     "years_elapsed" => 30.0,
    #     "planets" => [ { "planet" => "太陽", "zodiac" => "獅子座",
    #                      "degree" => 9.87, "total_degree" => 129.87,
    #                      "natal_house" => 3 }, ... 12 entries ],
    #     "aspects_to_natal" => [ { "progressed_planet" => "月亮",
    #                               "natal_planet" => "金星",
    #                               "aspect_type" => "三分相", "orb" => 0.4 }, ... ]
    #   }
    #
    # aspects_to_natal are sorted by orb (tightest first).
    def self.secondary(natal_chart, target_date, orb_limit: 1.0)
      input = natal_chart&.dig("input")
      if input.nil? || input["birth_date"].nil? || input["birth_time"].nil? || input["timezone"].nil?
        raise ArgumentError, "chart has no input data (birth_date/birth_time/timezone required)"
      end

      jd_natal  = TimeConversion.to_julian_day(input["birth_date"], input["birth_time"], input["timezone"])
      jd_target = TimeConversion.to_julian_day(target_date, input["birth_time"], input["timezone"])

      years_elapsed = (jd_target - jd_natal) / DAYS_PER_YEAR
      jd_prog = jd_natal + years_elapsed # a day for a year

      progressed_positions = Planets.calculate_positions(jd_prog)
      natal_positions      = Synastry.positions_from_chart(natal_chart)
      natal_cusps          = Synastry.cusps_from_chart(natal_chart)

      {
        "progressed_jd" => jd_prog,
        "years_elapsed" => years_elapsed.round(2),
        "planets" => Transits.planet_details(progressed_positions, natal_cusps),
        "aspects_to_natal" => Transits.aspects_to_natal(
          progressed_positions, natal_positions,
          orb_limit: orb_limit,
          keys: %w[progressed_planet natal_planet]
        ),
      }
    end
  end
end
