module AstroChart
  class Chart
    # Supported house systems: "P" (Placidus) / "W" (Whole Sign) /
    # "E" (Equal, from the ascendant) / "O" (Porphyry).
    HOUSE_SYSTEMS = ["P", "W", "E", "O"].freeze

    # Bodies that can never be retrograde in geocentric longitude.
    NEVER_RETROGRADE = ["太陽", "月亮"].freeze

    attr_reader :birth_date, :birth_time, :latitude, :longitude, :timezone,
                :house_system

    # birth_date: "YYYY-MM-DD"
    # birth_time: "HH:MM"
    # latitude / longitude: Float
    # timezone: IANA timezone string (e.g. "Asia/Taipei")
    # house_system: "P" (Placidus, default), "W" (Whole Sign),
    #               "E" (Equal, from the ascendant) or "O" (Porphyry)
    def initialize(birth_date:, birth_time:, latitude:, longitude:, timezone:,
                   house_system: "P")
      unless HOUSE_SYSTEMS.include?(house_system)
        raise ArgumentError,
              "unknown house system #{house_system.inspect} " \
              "(expected \"P\", \"W\", \"E\" or \"O\")"
      end

      @birth_date   = birth_date
      @birth_time   = birth_time
      @latitude     = latitude.to_f
      @longitude    = longitude.to_f
      @timezone     = timezone
      @house_system = house_system
    end

    # Generate complete chart data.
    # Returns a Hash with string keys, compatible with the existing JSON API.
    def generate
      jd = TimeConversion.to_julian_day(birth_date, birth_time, timezone)

      cusps, ascendant = Houses.calculate(jd, latitude, longitude, system: house_system)
      asc_zodiac = Zodiac.sign_name(ascendant)

      positions = Planets.calculate_positions(jd)
      planet_details = Planets.build_details(positions, cusps)

      # Retrograde flags for the 12 physical bodies (太陽/月亮 hard-false,
      # 南交點 mirrors 北交點 — they share the same axis).
      retro = retrograde_flags(jd)
      planet_details.each { |p| p["retrograde"] = retro.fetch(p["planet"], false) }

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

      # Derived points (福點 / 莉莉絲), placed before the ruler points
      planet_details.concat(derived_points(jd, positions, cusps, ascendant))

      # Append ruler points (定位星 carry no retrograde motion of their own)
      ruler_points = kp["additional_points"].map { |p| p.merge("retrograde" => false) }
      planet_details.concat(ruler_points)

      houses_data = cusps.each_with_index.map do |deg, i|
        {
          "house_number" => i + 1,
          "degree"       => deg.round(4),
          "zodiac"       => Zodiac.sign_name(deg),
        }
      end

      # 12-body positions feed pattern detection; the 10 classical planets
      # (nodes excluded) feed the element/modality statistics.
      classical = positions.reject { |name, _| name == "北交點" || name == "南交點" }

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
          "house_system"  => house_system,
          "planets"       => planet_details,
          "houses"        => houses_data,
          "patterns"      => Patterns.detect(positions),
          "element_stats" => Stats.elements(classical),
        },
      }
    end

    private

    # { "太陽" => false, ..., "南交點" => bool } — retrograde flags per body.
    def retrograde_flags(jd)
      flags = {}
      Ephemeris::PLANETS.each do |name, planet_id|
        flags[name] = if NEVER_RETROGRADE.include?(name)
                        false
                      else
                        Ephemeris.retrograde?(jd, planet_id)
                      end
      end
      flags["南交點"] = flags["北交點"]
      flags
    end

    # 福點 (Part of Fortune) + 莉莉絲 (mean Black Moon Lilith) entries,
    # shaped like regular planet entries. Both are hard-false retrograde:
    # 福點 is a derived point with no motion of its own; 莉莉絲 is the mean
    # lunar apogee, which always moves prograde.
    def derived_points(jd, positions, cusps, ascendant)
      # Sect (day/night) is an astronomical fact defined by the Sun relative
      # to the ASC-DSC horizon axis, so it is judged from the horizon itself
      # — never from the selected display house system's cusps (whole-sign
      # cusps sit on sign boundaries, not on the horizon).
      day_chart = Points.day_chart_from_horizon?(positions["太陽"], ascendant)
      fortune = Points.fortune(
        asc: ascendant,
        sun: positions["太陽"],
        moon: positions["月亮"],
        day_chart: !!day_chart
      )
      lilith = Points.lilith(jd)

      [point_entry("福點", fortune, cusps), point_entry("莉莉絲", lilith, cusps)]
    end

    def point_entry(name, pos, cusps)
      {
        "planet"       => name,
        "zodiac"       => Zodiac.sign_name(pos),
        "house"        => Houses.find_house(pos, cusps),
        "degree"       => (pos % 30).round(4),
        "total_degree" => pos.round(4),
        "retrograde"   => false,
      }
    end
  end
end
