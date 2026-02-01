require "spec_helper"

RSpec.describe AstroChart::Chart do
  describe "#generate" do
    subject(:result) do
      chart = described_class.new(
        birth_date: "1990-01-01",
        birth_time: "12:00",
        latitude: 25.0330,
        longitude: 121.5654,
        timezone: "Asia/Taipei"
      )
      chart.generate
    end

    it "returns a hash with input and chart sections" do
      expect(result).to have_key("input")
      expect(result).to have_key("chart")
    end

    it "includes input parameters" do
      input = result["input"]
      expect(input["birth_date"]).to eq("1990-01-01")
      expect(input["birth_time"]).to eq("12:00")
      expect(input["coordinates"]["latitude"]).to eq(25.0330)
      expect(input["coordinates"]["longitude"]).to eq(121.5654)
      expect(input["timezone"]).to eq("Asia/Taipei")
    end

    it "includes ascendant info" do
      asc = result["chart"]["ascendant"]
      expect(asc).to have_key("zodiac")
      expect(asc).to have_key("degree")
      expect(asc).to have_key("total_degree")
      expect(AstroChart::Zodiac::SIGNS).to include(asc["zodiac"])
    end

    it "includes 12 planets + nodes" do
      planets = result["chart"]["planets"]
      planet_names = planets.map { |p| p["planet"] }

      %w[太陽 月亮 水星 金星 火星 木星 土星 天王星 海王星 冥王星 北交點 南交點].each do |name|
        expect(planet_names).to include(name)
      end
    end

    it "includes ruler points (定位星)" do
      planets = result["chart"]["planets"]
      ruler_names = planets.map { |p| p["planet"] }

      expect(ruler_names).to include("北交點定位星")
      expect(ruler_names).to include("南交點定位星")
      expect(ruler_names).to include("上升星座定位星")
    end

    it "includes aspects for key planets" do
      planets = result["chart"]["planets"]
      sun = planets.find { |p| p["planet"] == "太陽" }
      expect(sun).to have_key("aspects")
    end

    it "includes 12 houses" do
      houses = result["chart"]["houses"]
      expect(houses.length).to eq(12)

      houses.each_with_index do |h, i|
        expect(h["house_number"]).to eq(i + 1)
        expect(h).to have_key("degree")
        expect(h).to have_key("zodiac")
      end
    end

    it "has all string keys (no symbol keys)" do
      # Deep check for string keys
      check_string_keys = ->(obj) do
        case obj
        when Hash
          obj.each do |k, v|
            expect(k).to be_a(String), "Expected string key, got #{k.class}: #{k}"
            check_string_keys.call(v)
          end
        when Array
          obj.each { |v| check_string_keys.call(v) }
        end
      end

      check_string_keys.call(result)
    end
  end
end
