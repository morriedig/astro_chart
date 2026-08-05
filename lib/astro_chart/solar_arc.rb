require_relative "time_conversion"
require_relative "planets"
require_relative "synastry"
require_relative "transits"

module AstroChart
  # Solar arc directions (太陽弧正向推運): advance every natal point by a single
  # arc — the distance the secondary-progressed Sun has travelled since birth.
  # Unlike secondary progressions (where each body moves at its own rate),
  # solar arc moves the whole chart rigidly, so directed-to-natal aspects
  # perfect at a rate of ~1° per year of life.
  #
  #   natal  = AstroChart::Chart.new(...).generate
  #   result = AstroChart::SolarArc.directions(natal, "2026-07-24")
  #   result["arc"]              # degrees the chart has been directed (~age)
  #   result["planets"]          # directed positions + natal-house placement
  #   result["aspects_to_natal"] # directed→natal aspects, sorted by orb
  module SolarArc
    DAYS_PER_YEAR = 365.2425 # matches Progressions

    SUN = "太陽"

    # natal_chart: a Chart#generate result hash (its input block gives birth
    #   date/time/timezone). target_date: "YYYY-MM-DD".
    # orb_limit: keep only directed-to-natal aspects within this orb (default
    #   1.0 — solar arc is slow, only near-exact contacts matter).
    def self.directions(natal_chart, target_date, orb_limit: 1.0)
      input = natal_chart&.dig("input")
      if input.nil? || input["birth_date"].nil? || input["birth_time"].nil? || input["timezone"].nil?
        raise ArgumentError, "chart has no input data (birth_date/birth_time/timezone required)"
      end

      jd_natal  = TimeConversion.to_julian_day(input["birth_date"], input["birth_time"], input["timezone"])
      jd_target = TimeConversion.to_julian_day(target_date, input["birth_time"], input["timezone"])
      jd_prog   = jd_natal + (jd_target - jd_natal) / DAYS_PER_YEAR # a day for a year

      natal_positions = Synastry.positions_from_chart(natal_chart)
      natal_cusps     = Synastry.cusps_from_chart(natal_chart)

      natal_sun = natal_positions[SUN] || Planets.calculate_positions(jd_natal)[SUN]
      prog_sun  = Planets.calculate_positions(jd_prog)[SUN]
      # The Sun only ever moves forward, so the forward arc is the plain
      # modular difference (< 360° for any human lifespan).
      arc = (prog_sun - natal_sun) % 360.0

      directed_positions = natal_positions.transform_values { |lon| (lon + arc) % 360.0 }

      {
        "arc" => arc.round(4),
        "planets" => Transits.planet_details(directed_positions, natal_cusps),
        "aspects_to_natal" => Transits.aspects_to_natal(
          directed_positions, natal_positions,
          orb_limit: orb_limit,
          keys: %w[directed_planet natal_planet]
        ),
      }
    end
  end
end
