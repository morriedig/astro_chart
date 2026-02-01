require "spec_helper"

RSpec.describe AstroChart::Planets do
  describe ".calculate_positions" do
    it "returns positions for all planets and nodes" do
      # J2000.0 epoch
      jd = AstroChart::Ephemeris.julday(2000, 1, 1, 12.0)
      positions = described_class.calculate_positions(jd)

      expected_keys = %w[太陽 月亮 水星 金星 火星 木星 土星 天王星 海王星 冥王星 北交點 南交點]
      expected_keys.each do |key|
        expect(positions).to have_key(key)
        expect(positions[key]).to be_a(Float)
        expect(positions[key]).to be >= 0
        expect(positions[key]).to be < 360
      end
    end

    it "calculates south node as north node + 180" do
      jd = AstroChart::Ephemeris.julday(2000, 1, 1, 12.0)
      positions = described_class.calculate_positions(jd)

      expected_sn = (positions["北交點"] + 180.0) % 360.0
      expect(positions["南交點"]).to be_within(0.0001).of(expected_sn)
    end

    it "gives reasonable Sun position for J2000 (should be near Capricorn ~280 degrees)" do
      jd = AstroChart::Ephemeris.julday(2000, 1, 1, 12.0)
      positions = described_class.calculate_positions(jd)
      # Sun on Jan 1 2000 is around 280 degrees (Capricorn)
      expect(positions["太陽"]).to be_within(5).of(280)
    end
  end

  describe ".aspects_for" do
    it "finds aspects between a point and planet positions" do
      positions = { "太陽" => 0.0, "月亮" => 90.0, "水星" => 40.0 }
      aspects = described_class.aspects_for(0.0, "太陽", positions)

      moon_aspect = aspects.find { |a| a["planet"] == "月亮" }
      expect(moon_aspect).not_to be_nil
      expect(moon_aspect["aspect_type"]).to eq("四分相")
    end

    it "excludes the point itself" do
      positions = { "太陽" => 0.0, "月亮" => 90.0 }
      aspects = described_class.aspects_for(0.0, "太陽", positions)

      sun_aspect = aspects.find { |a| a["planet"] == "太陽" }
      expect(sun_aspect).to be_nil
    end
  end
end
