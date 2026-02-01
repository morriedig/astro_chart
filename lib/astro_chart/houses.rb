module AstroChart
  module Houses
    # Calculate house cusps and ascendant from Julian Day + coordinates.
    # Returns [cusps_array(12), ascendant_degree].
    def self.calculate(jd, latitude, longitude, system = "P")
      data = Ephemeris.houses(jd, latitude, longitude, system)
      [data["cusps"], data["ascendant"]]
    end

    # Determine which house (1-12) a planet falls in based on house cusps.
    def self.find_house(planet_pos, cusps)
      return nil if planet_pos.nil? || cusps.nil? || cusps.empty?

      n = cusps.length
      base = cusps[0]

      # Normalize house cusps relative to first house cusp
      norm_cusps = cusps.map { |h| h >= base ? h : h + 360.0 }
      norm_pos = planet_pos >= base ? planet_pos : planet_pos + 360.0

      n.times do |i|
        start_deg = norm_cusps[i]
        end_deg = i < n - 1 ? norm_cusps[i + 1] : norm_cusps[0] + 360.0
        return i + 1 if norm_pos >= start_deg && norm_pos < end_deg
      end

      nil
    end
  end
end
