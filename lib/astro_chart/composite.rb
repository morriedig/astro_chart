module AstroChart
  # Composite chart (組合盤): the midpoint chart of two natal charts.
  #
  # For every body present in BOTH charts, the composite position is the
  # shorter-arc midpoint of the two natal longitudes. Aspects are then
  # computed among the composite positions themselves.
  #
  # Backend-independent: works purely on Chart#generate result hashes,
  # no ephemeris call happens here.
  #
  #   result = Composite.between(chart_a, chart_b)
  #   result["planets"] # 12 個組合盤中點位置
  #   result["aspects"] # 組合盤位置彼此之間的相位（依 orb 排序）
  #
  # Houses are intentionally out of scope: midpoint-composite house systems
  # are convention-contested (midpoint of cusps vs. recomputed for a
  # reference location/time), so no single answer is returned here.
  module Composite
    # The 12 bodies considered: the 11 ephemeris bodies + 南交點.
    BODIES = (Ephemeris::PLANETS.keys + ["南交點"]).freeze

    # Full composite between two Chart#generate result hashes.
    #
    # Returns:
    #   {
    #     "planets" => [{ "planet", "zodiac", "degree", "total_degree" }],
    #     "aspects" => [{ "planet_a", "planet_b", "aspect_type", "orb" }],
    #   }
    def self.between(chart_a, chart_b)
      pos_a = positions_from_chart(chart_a)
      pos_b = positions_from_chart(chart_b)

      composite_positions = {}
      BODIES.each do |name|
        a = pos_a[name]
        b = pos_b[name]
        next if a.nil? || b.nil?

        composite_positions[name] = midpoint(a, b)
      end

      {
        "planets" => build_planets(composite_positions),
        "aspects" => build_aspects(composite_positions),
      }
    end

    # Shorter-arc midpoint of two ecliptic longitudes (degrees, [0, 360)).
    # 350° & 10° => 0° (not 180°).
    def self.midpoint(a, b)
      (a + (((b - a + 540.0) % 360.0) - 180.0) / 2.0) % 360.0
    end

    # Extract { name => total_degree } for BODIES from a Chart#generate hash.
    # Ruler points appended by key_points_data are ignored (not in BODIES).
    def self.positions_from_chart(chart)
      planets = chart&.dig("chart", "planets")
      raise ArgumentError, "chart has no planets data" if planets.nil? || planets.empty?

      planets.each_with_object({}) do |p, out|
        name = p["planet"]
        next unless BODIES.include?(name)

        degree = p["total_degree"]
        out[name] = degree if degree
      end
    end

    def self.build_planets(positions)
      positions.map do |name, pos|
        {
          "planet"       => name,
          "zodiac"       => Zodiac.sign_name(pos),
          "degree"       => (pos % 30).round(4),
          "total_degree" => pos.round(4),
        }
      end
    end

    def self.build_aspects(positions)
      names = positions.keys
      results = []

      names.combination(2) do |name_a, name_b|
        aspect_type, orb = Aspects.calculate(positions[name_a], positions[name_b])
        next if aspect_type.nil?

        results << {
          "planet_a"    => name_a,
          "planet_b"    => name_b,
          "aspect_type" => aspect_type,
          "orb"         => orb,
        }
      end

      results.sort_by { |r| r["orb"] }
    end

    private_class_method :build_planets, :build_aspects
  end
end
