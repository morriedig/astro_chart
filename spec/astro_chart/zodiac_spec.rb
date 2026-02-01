require "spec_helper"

RSpec.describe AstroChart::Zodiac do
  describe ".sign_name" do
    it "returns 牡羊座 for 0-29 degrees" do
      expect(described_class.sign_name(0)).to eq("牡羊座")
      expect(described_class.sign_name(15)).to eq("牡羊座")
      expect(described_class.sign_name(29.99)).to eq("牡羊座")
    end

    it "returns 金牛座 for 30-59 degrees" do
      expect(described_class.sign_name(30)).to eq("金牛座")
      expect(described_class.sign_name(45)).to eq("金牛座")
    end

    it "returns 雙子座 for 60-89 degrees" do
      expect(described_class.sign_name(60)).to eq("雙子座")
    end

    it "returns 巨蟹座 for 90-119 degrees" do
      expect(described_class.sign_name(90)).to eq("巨蟹座")
    end

    it "returns 獅子座 for 120-149 degrees" do
      expect(described_class.sign_name(120)).to eq("獅子座")
    end

    it "returns 處女座 for 150-179 degrees" do
      expect(described_class.sign_name(150)).to eq("處女座")
    end

    it "returns 天秤座 for 180-209 degrees" do
      expect(described_class.sign_name(180)).to eq("天秤座")
    end

    it "returns 天蠍座 for 210-239 degrees" do
      expect(described_class.sign_name(210)).to eq("天蠍座")
    end

    it "returns 射手座 for 240-269 degrees" do
      expect(described_class.sign_name(240)).to eq("射手座")
    end

    it "returns 摩羯座 for 270-299 degrees" do
      expect(described_class.sign_name(270)).to eq("摩羯座")
    end

    it "returns 水瓶座 for 300-329 degrees" do
      expect(described_class.sign_name(300)).to eq("水瓶座")
    end

    it "returns 雙魚座 for 330-359 degrees" do
      expect(described_class.sign_name(330)).to eq("雙魚座")
      expect(described_class.sign_name(359.99)).to eq("雙魚座")
    end

    it "normalizes degrees >= 360" do
      expect(described_class.sign_name(360)).to eq("牡羊座")
      expect(described_class.sign_name(390)).to eq("金牛座")
    end
  end

  describe ".ruler" do
    it "returns correct rulers" do
      expect(described_class.ruler("牡羊座")).to eq("火星")
      expect(described_class.ruler("金牛座")).to eq("金星")
      expect(described_class.ruler("雙子座")).to eq("水星")
      expect(described_class.ruler("巨蟹座")).to eq("月亮")
      expect(described_class.ruler("獅子座")).to eq("太陽")
      expect(described_class.ruler("處女座")).to eq("水星")
      expect(described_class.ruler("天秤座")).to eq("金星")
      expect(described_class.ruler("天蠍座")).to eq("冥王星")
      expect(described_class.ruler("射手座")).to eq("木星")
      expect(described_class.ruler("摩羯座")).to eq("土星")
      expect(described_class.ruler("水瓶座")).to eq("天王星")
      expect(described_class.ruler("雙魚座")).to eq("海王星")
    end

    it "raises for invalid zodiac" do
      expect { described_class.ruler("無效") }.to raise_error(ArgumentError)
    end
  end
end
