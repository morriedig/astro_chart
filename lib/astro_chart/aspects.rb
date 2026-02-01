module AstroChart
  module Aspects
    # Major aspects: angle => [name, max_orb]
    MAJOR = {
      60  => ["六分相", 6],   # Sextile
      90  => ["四分相", 8],   # Square
      120 => ["三分相", 8],   # Trine
      180 => ["對分相", 10],  # Opposition
    }.freeze

    CONJUNCTION_ORB = 15

    # Calculate the aspect between two ecliptic positions.
    # Returns [aspect_name, orb] or [nil, nil].
    def self.calculate(pos1, pos2)
      return [nil, nil] if pos1.nil? || pos2.nil?

      p1 = pos1 % 360.0
      p2 = pos2 % 360.0

      diff = (p1 - p2).abs % 360.0
      diff = 360.0 - diff if diff > 180.0

      # Conjunction (widest orb)
      if diff <= CONJUNCTION_ORB
        return ["合相", diff.round(2)]
      end

      # Check major aspects
      MAJOR.each do |angle, (name, max_orb)|
        orb = (diff - angle).abs
        if orb <= max_orb
          return [name, orb.round(2)]
        end
      end

      [nil, nil]
    end
  end
end
