module AstroChart
  class Chart
    attr_reader :birth_date, :birth_time, :latitude, :longitude, :timezone

    # birth_date: "YYYY-MM-DD"
    # birth_time: "HH:MM"
    # latitude / longitude: Float
    # timezone: IANA timezone string (e.g. "Asia/Taipei")
    def initialize(birth_date:, birth_time:, latitude:, longitude:, timezone:)
      @birth_date = birth_date
      @birth_time = birth_time
      @latitude   = latitude.to_f
      @longitude  = longitude.to_f
      @timezone   = timezone
    end

    # Generate complete chart data.
    # Returns a Hash with string keys, compatible with the existing JSON API.
    def generate
      jd = TimeConversion.to_julian_day(birth_date, birth_time, timezone)

      cusps, ascendant = Houses.calculate(jd, latitude, longitude)
      asc_zodiac = Zodiac.sign_name(ascendant)

      positions = Planets.calculate_positions(jd)
      planet_details = Planets.build_details(positions, cusps)

      kp = Planets.key_points_data(positions, cusps, ascendant)

      # Merge aspects into planet details
      aspect_map = {
        "太陽"  => "sun_aspects",
        "月亮"  => "moon_aspects",
        "土星"  => "saturn_aspects",
        "金星"  => "venus_aspects",
        "北交點" => "north_node_aspects",
        "南交點" => "south_node_aspects",
      }

      planet_details.each do |planet|
        key = aspect_map[planet["planet"]]
        planet["aspects"] = kp[key] if key
      end

      # Append ruler points
      planet_details.concat(kp["additional_points"])

      houses_data = cusps.each_with_index.map do |deg, i|
        {
          "house_number" => i + 1,
          "degree"       => deg.round(4),
          "zodiac"       => Zodiac.sign_name(deg),
        }
      end

      {
        "input" => {
          "birth_date"  => birth_date,
          "birth_time"  => birth_time,
          "coordinates" => {
            "latitude"  => latitude,
            "longitude" => longitude,
          },
          "timezone"    => timezone,
        },
        "chart" => {
          "ascendant" => {
            "zodiac"       => asc_zodiac,
            "degree"       => (ascendant % 30).round(4),
            "total_degree" => ascendant.round(4),
          },
          "planets" => planet_details,
          "houses"  => houses_data,
        },
      }
    end
  end
end
