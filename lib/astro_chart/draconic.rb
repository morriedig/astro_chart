require_relative "zodiac"
require_relative "aspects"

module AstroChart
  # Draconic chart (龍盤): the tropical zodiac rotated so the natal True North
  # Node sits at 0° 牡羊. Every ecliptic longitude is shifted by the node's
  # longitude, which re-signs the whole chart around the lunar nodal axis.
  # Widely read as the "soul level" overlay of the ordinary tropical chart.
  #
  #   draconic_longitude = (L − 北交點) mod 360
  #
  # Pure composition: this only transforms longitudes. Feed it the raw
  # positions hash from `Planets.calculate_positions` (or any { name => L }
  # hash) together with the natal True North Node longitude.
  module Draconic
    # positions:  { "太陽" => 123.45, ... } tropical ecliptic longitudes
    # north_node: True North Node longitude (degrees, 0-360)
    #
    # Returns { name => draconic_longitude } with 北交點 mapped to 0.0.
    def self.positions(positions, north_node)
      positions.transform_values { |lon| (lon - north_node) % 360.0 }
    end

    # Full draconic view: draconic longitude, zodiac sign and in-sign degree
    # for every body, plus the aspects among them (major aspects only, via
    # Aspects.calculate — draconic-to-draconic contacts are identical to the
    # tropical ones, but the signs and houses they fall in differ).
    #
    # Returns:
    #   { "planets" => [ { "planet" =>, "zodiac" =>, "degree" =>,
    #                      "total_degree" => }, ... ],
    #     "aspects" => [ { "a_planet" =>, "b_planet" =>,
    #                      "aspect_type" =>, "orb" => }, ... ] }  # sorted by orb
    def self.chart(positions, north_node)
      draconic = self.positions(positions, north_node)

      planets = draconic.map do |name, lon|
        {
          "planet"       => name,
          "zodiac"       => Zodiac.sign_name(lon),
          "degree"       => (lon % 30).round(4),
          "total_degree" => lon.round(4),
        }
      end

      names = draconic.keys
      aspects = []
      names.combination(2) do |a, b|
        type, orb = Aspects.calculate(draconic[a], draconic[b])
        next if type.nil?

        aspects << {
          "a_planet"    => a,
          "b_planet"    => b,
          "aspect_type" => type,
          "orb"         => orb,
        }
      end
      aspects.sort_by! { |asp| asp["orb"] }

      { "planets" => planets, "aspects" => aspects }
    end
  end
end
