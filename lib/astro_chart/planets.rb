module AstroChart
  module Planets
    # Calculate raw ecliptic longitudes for all planets + nodes.
    # Returns Hash: { "太陽" => 123.45, "月亮" => 67.89, ... }
    def self.calculate_positions(jd)
      positions = {}

      Ephemeris::PLANETS.each do |name, planet_id|
        positions[name] = Ephemeris.calc_ut(jd, planet_id)
      end

      # South node = North node + 180
      positions["南交點"] = (positions["北交點"] + 180.0) % 360.0

      positions
    end

    # Build detailed planet info list with zodiac, house, degree.
    def self.build_details(positions, cusps)
      positions.map do |planet, pos|
        house = Houses.find_house(pos, cusps)
        next if house.nil?

        {
          "planet"       => planet,
          "zodiac"       => Zodiac.sign_name(pos),
          "house"        => house,
          "degree"       => (pos % 30).round(4),
          "total_degree" => pos.round(4),
        }
      end.compact
    end

    # Calculate aspects for a given point against all planet positions.
    def self.aspects_for(point_pos, point_name, positions)
      return [] if point_pos.nil?

      results = []
      positions.each do |planet, pos|
        next if planet == point_name

        aspect_type, orb = Aspects.calculate(point_pos, pos)
        if aspect_type
          results << {
            "planet"      => planet,
            "aspect_type" => aspect_type,
            "orb"         => orb,
          }
        end
      end
      results
    end

    # Calculate key points data: aspects for major planets + ruler info.
    def self.key_points_data(positions, cusps, ascendant)
      sun_aspects         = aspects_for(positions["太陽"],  "太陽",  positions)
      moon_aspects        = aspects_for(positions["月亮"],  "月亮",  positions)
      saturn_aspects      = aspects_for(positions["土星"],  "土星",  positions)
      venus_aspects       = aspects_for(positions["金星"],  "金星",  positions)
      north_node_aspects  = aspects_for(positions["北交點"], "北交點", positions)
      south_node_aspects  = aspects_for(positions["南交點"], "南交點", positions)

      additional_points = []

      # North Node ruler
      nn_pos = positions["北交點"]
      if nn_pos
        nn_zodiac = Zodiac.sign_name(nn_pos)
        nn_ruler  = Zodiac.ruler(nn_zodiac)
        nn_ruler_pos = positions[nn_ruler]
        if nn_ruler_pos
          additional_points << build_ruler_point("北交點定位星", nn_ruler, nn_ruler_pos, cusps, positions)
        end
      end

      # South Node ruler
      sn_pos = positions["南交點"]
      if sn_pos
        sn_zodiac = Zodiac.sign_name(sn_pos)
        sn_ruler  = Zodiac.ruler(sn_zodiac)
        sn_ruler_pos = positions[sn_ruler]
        if sn_ruler_pos
          additional_points << build_ruler_point("南交點定位星", sn_ruler, sn_ruler_pos, cusps, positions)
        end
      end

      # Ascendant ruler
      if ascendant
        asc_zodiac = Zodiac.sign_name(ascendant)
        asc_ruler  = Zodiac.ruler(asc_zodiac)
        asc_ruler_pos = positions[asc_ruler]
        if asc_ruler_pos
          additional_points << build_ruler_point("上升星座定位星", asc_ruler, asc_ruler_pos, cusps, positions)
        end
      end

      {
        "sun_aspects"        => sun_aspects,
        "moon_aspects"       => moon_aspects,
        "saturn_aspects"     => saturn_aspects,
        "venus_aspects"      => venus_aspects,
        "north_node_aspects" => north_node_aspects,
        "south_node_aspects" => south_node_aspects,
        "additional_points"  => additional_points,
      }
    end

    private_class_method

    def self.build_ruler_point(label, ruling_planet, pos, cusps, positions)
      {
        "planet"        => label,
        "ruling_planet" => ruling_planet,
        "zodiac"        => Zodiac.sign_name(pos),
        "house"         => Houses.find_house(pos, cusps),
        "degree"        => (pos % 30).round(4),
        "total_degree"  => pos.round(4),
        "aspects"       => aspects_for(pos, ruling_planet, positions),
      }
    end
  end
end
