require_relative "spec_helper"
require "tzinfo"

RSpec.describe Cities do
  let(:cities) { described_class::CITIES }

  describe "CITIES data" do
    it "contains all 22 Taiwan counties/cities on Asia/Taipei" do
      taiwan = cities.select { |c| c["country"] == "台灣" }
      expect(taiwan.size).to eq(22)
      expect(taiwan.map { |c| c["timezone"] }.uniq).to eq(["Asia/Taipei"])
      expect(taiwan.map { |c| c["name"] }).to include(
        "台北市", "新北市", "桃園市", "台中市", "台南市", "高雄市",
        "基隆市", "新竹市", "嘉義市", "新竹縣", "苗栗縣", "彰化縣",
        "南投縣", "雲林縣", "嘉義縣", "屏東縣", "宜蘭縣", "花蓮縣",
        "台東縣", "澎湖縣", "金門縣", "連江縣"
      )
    end

    it "contains at least 120 world cities beyond Taiwan" do
      expect(cities.count { |c| c["country"] != "台灣" }).to be >= 120
    end

    it "has unique names" do
      names = cities.map { |c| c["name"] }
      expect(names.uniq.size).to eq(names.size)
    end

    it "gives every entry the full shape" do
      cities.each do |city|
        expect(city.keys).to match_array(%w[name alt country latitude longitude timezone])
        expect(city["name"]).to be_a(String)
        expect(city["alt"]).to be_an(Array)
        expect(city["alt"]).to all(be_a(String))
        expect(city["country"]).to be_a(String)
      end
    end

    it "keeps every coordinate in range" do
      cities.each do |city|
        expect(city["latitude"]).to be_between(-90, 90)
        expect(city["longitude"]).to be_between(-180, 180)
      end
    end

    it "uses only resolvable IANA timezones" do
      cities.map { |c| c["timezone"] }.uniq.each do |tz|
        expect { TZInfo::Timezone.get(tz) }.not_to raise_error
      end
    end

    it "matches known coordinates for landmark cities" do
      {
        "台北市" => [25.03, 121.56],
        "東京"   => [35.68, 139.69],
        "紐約"   => [40.71, -74.01],
        "倫敦"   => [51.51, -0.13],
        "巴黎"   => [48.86, 2.35],
        "雪梨"   => [-33.87, 151.21],
      }.each do |name, (lat, lng)|
        city = cities.find { |c| c["name"] == name }
        expect(city).not_to be_nil
        expect(city["latitude"]).to be_within(0.05).of(lat)
        expect(city["longitude"]).to be_within(0.05).of(lng)
      end
    end
  end

  describe ".search" do
    it "matches Chinese prefixes" do
      expect(described_class.search("台北").map { |c| c["name"] }).to include("台北市")
    end

    it "matches pinyin aliases" do
      expect(described_class.search("gaoxiong").map { |c| c["name"] }).to eq(["高雄市"])
    end

    it "returns [] for a blank query" do
      expect(described_class.search("")).to eq([])
    end

    it "returns at most 10 results" do
      expect(described_class.search("a").size).to be <= 10
    end

    it "puts prefix matches before substring matches" do
      names = described_class.search("lon").map { |c| c["name"] }
      expect(names.first).to eq("倫敦")
      expect(names).to include("巴塞隆納")
    end

    it "strips the alt key from results" do
      described_class.search("tokyo").each do |city|
        expect(city.keys).to match_array(%w[name country latitude longitude timezone])
      end
    end
  end
end
