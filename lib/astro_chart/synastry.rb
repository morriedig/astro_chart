module AstroChart
  # Synastry (合盤): cross-chart comparison between two natal charts.
  #
  # Pure composition of existing modules — Aspects.calculate works on any two
  # ecliptic longitudes regardless of which chart they come from, and
  # Houses.find_house places any longitude into any set of cusps.
  # Backend-independent: no ephemeris call happens here.
  #
  # Typical usage with two Chart#generate results:
  #
  #   result = Synastry.between(chart_a, chart_b)
  #   result["aspects"]               # A 的行星 × B 的行星 的跨盤相位
  #   result["a_planets_in_b_houses"] # A 的行星落在 B 的哪一宮（疊盤）
  #   result["b_planets_in_a_houses"] # B 的行星落在 A 的哪一宮
  module Synastry
    # Bodies used for cross-chart comparison.
    # 南交點 is excluded by default: it is always exactly opposite 北交點,
    # so including it would mirror every node aspect and double the noise.
    BODIES = Ephemeris::PLANETS.keys.freeze

    # Cross aspects between two position sets.
    #
    # positions_a / positions_b: { "太陽" => 123.45, ... } (ecliptic longitudes)
    # orb_limit: optional Float — keep only aspects with orb <= limit.
    #   (Aspects uses natal orbs: conjunction 15°, others 6-10°. Synastry
    #   practice often uses tighter orbs; pass e.g. orb_limit: 6.0 to tighten.)
    #
    # Returns Array of:
    #   { "a_planet" => "太陽", "b_planet" => "月亮",
    #     "aspect_type" => "三分相", "orb" => 1.23 }
    #
    # Note: (A太陽, B月亮) and (A月亮, B太陽) are different pairs —
    # they compare different positions, both are kept.
    def self.cross_aspects(positions_a, positions_b, orb_limit: nil)
      results = []
      positions_a.each do |name_a, pos_a|
        positions_b.each do |name_b, pos_b|
          aspect_type, orb = Aspects.calculate(pos_a, pos_b)
          next if aspect_type.nil?
          next if orb_limit && orb > orb_limit

          results << {
            "a_planet"    => name_a,
            "b_planet"    => name_b,
            "aspect_type" => aspect_type,
            "orb"         => orb,
          }
        end
      end
      results.sort_by { |r| r["orb"] }
    end

    # House overlay (疊盤): place one person's planets into the other
    # person's houses.
    #
    # positions: { "太陽" => 123.45, ... }
    # cusps: 12 house cusp degrees (cusps[0] = 1st house)
    #
    # Returns { "太陽" => 7, ... } (house number 1-12)
    def self.house_overlay(positions, cusps)
      positions.each_with_object({}) do |(name, pos), out|
        house = Houses.find_house(pos, cusps)
        out[name] = house if house
      end
    end

    # Full synastry between two Chart#generate result hashes.
    def self.between(chart_a, chart_b, orb_limit: nil)
      pos_a = positions_from_chart(chart_a)
      pos_b = positions_from_chart(chart_b)
      cusps_a = cusps_from_chart(chart_a)
      cusps_b = cusps_from_chart(chart_b)

      {
        "aspects"               => cross_aspects(pos_a, pos_b, orb_limit: orb_limit),
        "a_planets_in_b_houses" => house_overlay(pos_a, cusps_b),
        "b_planets_in_a_houses" => house_overlay(pos_b, cusps_a),
      }
    end

    # Extract { name => total_degree } for BODIES from a Chart#generate hash.
    # Ruler points appended by key_points_data are ignored (not in BODIES).
    def self.positions_from_chart(chart)
      planets = chart&.dig("chart", "planets")
      raise ArgumentError, "chart has no planets data" if planets.nil? || planets.empty?

      planets.each_with_object({}) do |p, out|
        name = p["planet"]
        next unless BODIES.include?(name)

        degree = p["total_degree"] || total_degree_from(p)
        out[name] = degree if degree
      end
    end

    # Extract the 12 cusp degrees (index 0 = 1st house) from a Chart#generate hash.
    def self.cusps_from_chart(chart)
      houses = chart&.dig("chart", "houses")
      raise ArgumentError, "chart has no houses data" if houses.nil? || houses.length != 12

      houses.sort_by { |h| h["house_number"] }.map { |h| h["degree"] }
    end

    # Fallback for older snapshots that only stored zodiac + in-sign degree.
    def self.total_degree_from(planet)
      zodiac = planet["zodiac"]
      degree = planet["degree"]
      return nil if zodiac.nil? || degree.nil?

      sign_index = Zodiac::SIGNS.index(zodiac)
      return nil if sign_index.nil?

      sign_index * 30.0 + degree
    end

    private_class_method :total_degree_from
  end
end
