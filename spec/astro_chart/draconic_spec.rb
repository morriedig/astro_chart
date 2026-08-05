require "spec_helper"
require "astro_chart/draconic"

RSpec.describe AstroChart::Draconic do
  let(:positions) do
    { "太陽" => 100.0, "月亮" => 130.0, "北交點" => 40.0, "南交點" => 220.0 }
  end

  describe ".positions" do
    it "shifts every longitude so the North Node sits at 0° 牡羊" do
      draconic = described_class.positions(positions, positions["北交點"])
      expect(draconic["北交點"]).to be_within(1e-9).of(0.0)
      expect(draconic["太陽"]).to be_within(1e-9).of(60.0)   # 100 - 40
      expect(draconic["月亮"]).to be_within(1e-9).of(90.0)   # 130 - 40
      expect(draconic["南交點"]).to be_within(1e-9).of(180.0) # 220 - 40
    end

    it "wraps below zero back into 0-360" do
      draconic = described_class.positions({ "水星" => 10.0 }, 40.0)
      expect(draconic["水星"]).to be_within(1e-9).of(330.0)
    end

    it "preserves the relative angles between bodies" do
      draconic = described_class.positions(positions, positions["北交點"])
      natal_gap = (positions["月亮"] - positions["太陽"]) % 360.0
      drac_gap  = (draconic["月亮"] - draconic["太陽"]) % 360.0
      expect(drac_gap).to be_within(1e-9).of(natal_gap)
    end
  end

  describe ".chart" do
    subject(:chart) { described_class.chart(positions, positions["北交點"]) }

    it "reports draconic zodiac signs and in-sign degrees" do
      node = chart["planets"].find { |p| p["planet"] == "北交點" }
      expect(node["zodiac"]).to eq("牡羊座")
      expect(node["degree"]).to eq(0.0)

      moon = chart["planets"].find { |p| p["planet"] == "月亮" }
      expect(moon["zodiac"]).to eq("巨蟹座") # 90° = 0° 巨蟹
    end

    it "reports aspects among the draconic positions, sorted by orb" do
      # 太陽(60) 月亮(90): 30° apart → no major aspect; 太陽-南交點(180) 120° trine
      orbs = chart["aspects"].map { |a| a["orb"] }
      expect(orbs).to eq(orbs.sort)
      types = chart["aspects"].map { |a| a["aspect_type"] }
      expect(types).to all(be_a(String))
    end
  end
end
