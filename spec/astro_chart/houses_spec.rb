require "spec_helper"

RSpec.describe AstroChart::Houses do
  describe ".find_house" do
    let(:cusps) do
      # Roughly equal 30-degree cusps starting at 10 degrees
      [10.0, 40.0, 70.0, 100.0, 130.0, 160.0, 190.0, 220.0, 250.0, 280.0, 310.0, 340.0]
    end

    it "returns house 1 for planet near first cusp" do
      expect(described_class.find_house(20.0, cusps)).to eq(1)
    end

    it "returns house 2 for planet at 50 degrees" do
      expect(described_class.find_house(50.0, cusps)).to eq(2)
    end

    it "returns house 12 for planet at 350 degrees" do
      expect(described_class.find_house(350.0, cusps)).to eq(12)
    end

    it "returns house 1 for planet exactly on cusp 1" do
      expect(described_class.find_house(10.0, cusps)).to eq(1)
    end

    it "returns nil for nil position" do
      expect(described_class.find_house(nil, cusps)).to be_nil
    end

    it "returns nil for empty cusps" do
      expect(described_class.find_house(100.0, [])).to be_nil
    end

    context "when cusps wrap around 0 degrees" do
      let(:wrapping_cusps) do
        [300.0, 330.0, 0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0]
      end

      it "handles planet at 350 degrees (house 2)" do
        expect(described_class.find_house(350.0, wrapping_cusps)).to eq(2)
      end

      it "handles planet at 15 degrees (house 3)" do
        expect(described_class.find_house(15.0, wrapping_cusps)).to eq(3)
      end
    end
  end
end
