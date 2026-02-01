module AstroChart
  module Zodiac
    SIGNS = [
      "牡羊座", "金牛座", "雙子座", "巨蟹座",
      "獅子座", "處女座", "天秤座", "天蠍座",
      "射手座", "摩羯座", "水瓶座", "雙魚座"
    ].freeze

    RULERS = {
      "牡羊座" => "火星",
      "金牛座" => "金星",
      "雙子座" => "水星",
      "巨蟹座" => "月亮",
      "獅子座" => "太陽",
      "處女座" => "水星",
      "天秤座" => "金星",
      "天蠍座" => "冥王星",
      "射手座" => "木星",
      "摩羯座" => "土星",
      "水瓶座" => "天王星",
      "雙魚座" => "海王星",
    }.freeze

    # Return zodiac sign name for a given ecliptic longitude.
    def self.sign_name(degree)
      index = (degree % 360).floor / 30
      SIGNS[index]
    end

    # Return the ruling planet of a zodiac sign.
    def self.ruler(zodiac)
      r = RULERS[zodiac]
      raise ArgumentError, "無效的星座名稱: #{zodiac}" if r.nil?
      r
    end
  end
end
