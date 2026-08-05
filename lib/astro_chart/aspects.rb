module AstroChart
  module Aspects
    # Major aspects (托勒密相位): angle => [name, max_orb]
    MAJOR = {
      60  => ["六分相", 6],   # Sextile
      90  => ["四分相", 8],   # Square
      120 => ["三分相", 8],   # Trine
      180 => ["對分相", 10],  # Opposition
    }.freeze

    # Minor aspects (次要相位): angle => [name, max_orb]. Opt-in via
    # `minor: true` — they carry tighter orbs and are checked only after the
    # major set, so no minor aspect can shadow a major one (the angle bands
    # do not overlap given these orbs).
    #
    #   30°  十二分相  (semi-sextile)
    #   45°  半四分相  (semi-square)
    #   135° 補八分相  (sesquiquadrate)
    #   150° 補十二分相 (quincunx / inconjunct)
    MINOR = {
      30  => ["十二分相", 2],
      45  => ["半四分相", 2],
      135 => ["補八分相", 2],
      150 => ["補十二分相", 3],
    }.freeze

    CONJUNCTION_ORB = 15

    # Calculate the aspect between two ecliptic positions.
    #
    # By default only conjunction + the four major aspects are considered
    # (backward-compatible). Pass `minor: true` to also match the minor set.
    #
    # Returns [aspect_name, orb] or [nil, nil].
    def self.calculate(pos1, pos2, minor: false)
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

      if minor
        MINOR.each do |angle, (name, max_orb)|
          orb = (diff - angle).abs
          if orb <= max_orb
            return [name, orb.round(2)]
          end
        end
      end

      [nil, nil]
    end
  end
end
