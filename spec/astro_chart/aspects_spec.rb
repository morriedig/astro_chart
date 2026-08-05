require "spec_helper"

RSpec.describe AstroChart::Aspects do
  describe ".calculate" do
    it "detects conjunction (0 degrees, orb <= 15)" do
      type, orb = described_class.calculate(10, 10)
      expect(type).to eq("合相")
      expect(orb).to eq(0.0)
    end

    it "detects conjunction with orb" do
      type, orb = described_class.calculate(0, 12)
      expect(type).to eq("合相")
      expect(orb).to eq(12.0)
    end

    it "detects conjunction across 0 degrees" do
      type, orb = described_class.calculate(355, 5)
      expect(type).to eq("合相")
      expect(orb).to eq(10.0)
    end

    it "detects sextile (60 degrees, orb <= 6)" do
      type, orb = described_class.calculate(0, 60)
      expect(type).to eq("六分相")
      expect(orb).to eq(0.0)
    end

    it "detects sextile with orb" do
      type, orb = described_class.calculate(0, 65)
      expect(type).to eq("六分相")
      expect(orb).to eq(5.0)
    end

    it "detects square (90 degrees, orb <= 8)" do
      type, orb = described_class.calculate(0, 90)
      expect(type).to eq("四分相")
      expect(orb).to eq(0.0)
    end

    it "detects trine (120 degrees, orb <= 8)" do
      type, orb = described_class.calculate(0, 120)
      expect(type).to eq("三分相")
      expect(orb).to eq(0.0)
    end

    it "detects opposition (180 degrees, orb <= 10)" do
      type, orb = described_class.calculate(0, 180)
      expect(type).to eq("對分相")
      expect(orb).to eq(0.0)
    end

    it "detects opposition with orb" do
      type, orb = described_class.calculate(5, 190)
      expect(type).to eq("對分相")
      expect(orb).to eq(5.0)
    end

    it "returns nil for no aspect" do
      type, orb = described_class.calculate(0, 40)
      expect(type).to be_nil
      expect(orb).to be_nil
    end

    it "returns nil for nil positions" do
      type, orb = described_class.calculate(nil, 100)
      expect(type).to be_nil
    end
  end

  describe ".calculate with minor: true" do
    it "ignores minor aspects by default" do
      type, _orb = described_class.calculate(0, 150)
      expect(type).to be_nil
    end

    it "detects quincunx (150 degrees, orb <= 3)" do
      type, orb = described_class.calculate(0, 150, minor: true)
      expect(type).to eq("補十二分相")
      expect(orb).to eq(0.0)
    end

    it "detects quincunx with orb" do
      type, orb = described_class.calculate(0, 152, minor: true)
      expect(type).to eq("補十二分相")
      expect(orb).to eq(2.0)
    end

    it "detects semi-sextile (30 degrees, orb <= 2)" do
      type, orb = described_class.calculate(0, 30, minor: true)
      expect(type).to eq("十二分相")
      expect(orb).to eq(0.0)
    end

    it "detects semi-square (45 degrees, orb <= 2)" do
      type, orb = described_class.calculate(0, 45, minor: true)
      expect(type).to eq("半四分相")
      expect(orb).to eq(0.0)
    end

    it "detects sesquiquadrate (135 degrees, orb <= 2)" do
      type, orb = described_class.calculate(0, 135, minor: true)
      expect(type).to eq("補八分相")
      expect(orb).to eq(0.0)
    end

    it "does not let a minor aspect shadow a major one" do
      # 120° is a trine even with minor scanning enabled
      type, _orb = described_class.calculate(0, 120, minor: true)
      expect(type).to eq("三分相")
    end

    it "still returns nil where no aspect (minor) applies" do
      type, _orb = described_class.calculate(0, 40, minor: true)
      expect(type).to be_nil
    end
  end
end
