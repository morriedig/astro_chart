require "spec_helper"
require "astro_chart/dignities"

RSpec.describe AstroChart::Dignities do
  # Longitudes: 牡羊 0-30, 金牛 30-60, ... 獅子 120-150, 天秤 180-210, 水瓶 300-330
  describe "term tables" do
    it "gives each sign five Egyptian terms summing to 30° over the five non-luminaries" do
      described_class::EGYPTIAN_TERMS.each do |sign, terms|
        expect(terms.length).to eq(5)
        expect(terms.last[1]).to eq(30)
        rulers = terms.map { |r, _| r }
        expect(rulers.sort).to eq(%w[火星 木星 水星 金星 土星].sort)
      end
    end

    it "raises on an unknown term scheme" do
      expect { described_class.term_ruler(5.0, scheme: :ptolemaic) }
        .to raise_error(ArgumentError, /unknown term scheme/)
    end

    it "selects the term by degree within the sign" do
      # 牡羊: 木星 0-6, 金星 6-12, 水星 12-20, 火星 20-25, 土星 25-30
      expect(described_class.term_ruler(3.0)).to eq("木星")
      expect(described_class.term_ruler(24.9)).to eq("火星")
      expect(described_class.term_ruler(25.1)).to eq("土星")
      expect(described_class.term_ruler(30.0)).to eq("金星") # 0° 金牛
    end
  end

  describe "faces (Chaldean)" do
    it "starts 火星/太陽/金星 in 牡羊 and cycles the seven planets" do
      expect(described_class.face_ruler(0)).to eq("火星")
      expect(described_class.face_ruler(10)).to eq("太陽")
      expect(described_class.face_ruler(20)).to eq("金星")
      expect(described_class.face_ruler(120)).to eq("土星") # 獅子 I
    end
  end

  describe ".domicile_ruler / detriment / exaltation / fall (traditional)" do
    it "uses the traditional rulers, not the modern ones" do
      expect(described_class.domicile_ruler(215)).to eq("火星")  # 天蠍 → 火星 (not 冥王星)
      expect(described_class.domicile_ruler(310)).to eq("土星")  # 水瓶 → 土星 (not 天王星)
      expect(described_class.domicile_ruler(340)).to eq("木星")  # 雙魚 → 木星 (not 海王星)
    end

    it "detriment is the ruler of the opposite sign" do
      expect(described_class.detriment_ruler(5)).to eq("金星")   # 牡羊 → ruler of 天秤
    end

    it "exaltation and fall are opposite-sign mirrors" do
      expect(described_class.exaltation_ruler(5)).to eq("太陽")  # 太陽 exalts in 牡羊
      expect(described_class.fall_ruler(185)).to eq("太陽")      # 太陽 falls in 天秤
      expect(described_class.exaltation_ruler(125)).to be_nil    # 獅子 has no exalted planet
    end
  end

  describe ".triplicity_ruler (Dorothean, sect-aware)" do
    it "returns the day or night ruler by sect" do
      # 牡羊 is 火: day 太陽, night 木星, participating 土星
      expect(described_class.triplicity_ruler(5, sect: :day)).to eq("太陽")
      expect(described_class.triplicity_ruler(5, sect: :night)).to eq("木星")
      expect(described_class.triplicity_rulers(5)[:participating]).to eq("土星")
    end
  end

  describe ".of" do
    it "reports 火星 in its own sign 牡羊 as 廟 + 外觀" do
      report = described_class.of("火星", 5.0)
      expect(report["dignities"]).to contain_exactly("廟", "外觀")
      expect(report["debilities"]).to be_empty
      expect(report["score"]).to eq(6) # +5 domicile, +1 face
    end

    it "reports 太陽 in 天秤 as fallen (弱)" do
      report = described_class.of("太陽", 185.0)
      expect(report["debilities"]).to include("弱")
      expect(report["score"]).to eq(0)
    end

    it "scores 太陽 in 獅子 by day at +5 domicile +3 triplicity" do
      expect(described_class.of("太陽", 125.0, sect: :day)["score"]).to eq(8)
    end
  end

  describe ".almuten" do
    it "picks the highest-scoring traditional planet at a degree" do
      # 牡羊 5° by day: 太陽 gets exaltation(+4) + triplicity(+3) = 7, the max
      result = described_class.almuten(5.0, sect: :day)
      expect(result["planet"]).to eq("太陽")
      expect(result["score"]).to eq(7)
      expect(result["tied"]).to eq(["太陽"])
    end

    it "only ever awards the seven traditional planets" do
      (0...360).step(9) do |lon|
        winner = described_class.almuten(lon.to_f, sect: :day)["planet"]
        expect(described_class::PLANETS).to include(winner)
      end
    end
  end
end
