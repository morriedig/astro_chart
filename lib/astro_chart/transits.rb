require_relative "pure"
require_relative "ephemeris"
require_relative "zodiac"
require_relative "aspects"
require_relative "houses"
require_relative "planets"
require_relative "synastry"

module AstroChart
  # Transits (行運): where the planets are in the sky right now (or at any
  # moment), compared against a natal chart.
  #
  # Pure composition of existing modules — Planets.calculate_positions gives
  # the sky positions for any JD, Houses.find_house places them into the
  # natal houses, and Aspects.calculate scores transit-to-natal contacts.
  #
  # Typical usage with a Chart#generate result:
  #
  #   jd = AstroChart::TimeConversion.to_julian_day("2026-07-24", "12:00", "Asia/Taipei")
  #   AstroChart::Transits.at(jd)                  # 天象快照 { "太陽" => 121.9, ... }
  #   AstroChart::Transits.against(natal_chart, jd) # 行運行星落入本命宮位 + 行運相位
  module Transits
    # Bodies used for transit-to-natal aspects. Mirrors Synastry: 南交點 is
    # excluded because it sits exactly opposite 北交點 — every south-node
    # aspect would just mirror a north-node one and double the noise.
    ASPECT_BODIES = Synastry::BODIES

    # Sky snapshot at a Julian Day.
    #
    # Returns { "太陽" => 123.45, ..., "南交點" => 303.45 } — ecliptic
    # longitudes (total degrees 0-360) for the 12 bodies
    # (Ephemeris::PLANETS + 南交點 = 北交點 + 180°).
    def self.at(jd)
      Planets.calculate_positions(jd)
    end

    # Transits against a natal chart (a Chart#generate result hash).
    #
    # jd: Julian Day of the transit moment.
    # orb_limit: keep only aspects with orb <= limit (default 3.0 — transit
    #   practice uses much tighter orbs than the natal defaults in Aspects).
    #
    # Returns:
    #   {
    #     "planets" => [ { "planet" => "木星", "zodiac" => "獅子座",
    #                      "degree" => 5.1, "total_degree" => 125.1,
    #                      "natal_house" => 7 }, ... 12 entries ],
    #     "aspects" => [ { "transit_planet" => "土星", "natal_planet" => "太陽",
    #                      "aspect_type" => "四分相", "orb" => 1.23 }, ... ]
    #   }
    #
    # aspects are sorted by orb (tightest first).
    def self.against(natal_chart, jd, orb_limit: 3.0)
      transit_positions = at(jd)
      natal_positions   = Synastry.positions_from_chart(natal_chart)
      natal_cusps       = Synastry.cusps_from_chart(natal_chart)

      {
        "planets" => planet_details(transit_positions, natal_cusps),
        "aspects" => aspects_to_natal(transit_positions, natal_positions,
                                      orb_limit: orb_limit,
                                      keys: %w[transit_planet natal_planet]),
      }
    end

    # Build the per-planet detail list, placing each transiting body into
    # the natal houses.
    def self.planet_details(positions, natal_cusps)
      positions.map do |name, pos|
        {
          "planet"       => name,
          "zodiac"       => Zodiac.sign_name(pos),
          "degree"       => (pos % 30).round(4),
          "total_degree" => pos.round(4),
          "natal_house"  => Houses.find_house(pos, natal_cusps),
        }
      end
    end

    # Aspects from moving positions to natal positions, filtered by
    # orb_limit and sorted by orb. `keys` names the two hash keys so
    # Progressions can reuse this with "progressed_planet".
    def self.aspects_to_natal(moving_positions, natal_positions, orb_limit:,
                              keys: %w[transit_planet natal_planet])
      moving_key, natal_key = keys
      results = []

      moving_positions.each do |m_name, m_pos|
        next unless ASPECT_BODIES.include?(m_name)

        natal_positions.each do |n_name, n_pos|
          aspect_type, orb = Aspects.calculate(m_pos, n_pos)
          next if aspect_type.nil?
          next if orb_limit && orb > orb_limit

          results << {
            moving_key    => m_name,
            natal_key     => n_name,
            "aspect_type" => aspect_type,
            "orb"         => orb,
          }
        end
      end

      results.sort_by { |r| r["orb"] }
    end
  end
end
