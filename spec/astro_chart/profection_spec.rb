require "spec_helper"
require "astro_chart/profection"

RSpec.describe AstroChart::Profection do
  # Ascendant in 牡羊座 (longitude 10°)
  let(:aries_asc) { 10.0 }

  describe ".annual" do
    it "activates the 1st house (ASC sign) at age 0" do
      result = described_class.annual(aries_asc, 0)
      expect(result["profected_house"]).to eq(1)
      expect(result["profected_sign"]).to eq("牡羊座")
      expect(result["year_lord"]).to eq("火星")
    end

    it "advances one sign/house per year" do
      result = described_class.annual(aries_asc, 3)
      expect(result["profected_house"]).to eq(4)
      expect(result["profected_sign"]).to eq("巨蟹座")
      expect(result["year_lord"]).to eq("月亮")
    end

    it "cycles back to the 1st house every 12 years" do
      [12, 24, 36].each do |age|
        result = described_class.annual(aries_asc, age)
        expect(result["profected_house"]).to eq(1)
        expect(result["profected_sign"]).to eq("牡羊座")
      end
    end

    it "profects from whatever sign the ascendant sits in" do
      leo_asc = 125.0 # 獅子座
      result = described_class.annual(leo_asc, 1)
      expect(result["profected_house"]).to eq(2)
      expect(result["profected_sign"]).to eq("處女座")
      expect(result["year_lord"]).to eq("水星")
    end

    it "rejects a negative age" do
      expect { described_class.annual(aries_asc, -1) }
        .to raise_error(ArgumentError)
    end
  end

  describe ".at" do
    it "derives the age from birth and target dates" do
      result = described_class.at(aries_asc, "1990-01-01", "2026-08-05")
      expect(result["age"]).to eq(36)
    end

    it "counts a birthday not yet reached as the previous year" do
      # born 1990-06-15, target 2026-06-14 → 35 (birthday one day away)
      expect(described_class.at(aries_asc, "1990-06-15", "2026-06-14")["age"]).to eq(35)
      expect(described_class.at(aries_asc, "1990-06-15", "2026-06-15")["age"]).to eq(36)
    end
  end
end
