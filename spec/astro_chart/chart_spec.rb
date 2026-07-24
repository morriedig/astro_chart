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

    it "includes 17 planet entries in the documented order" do
      planet_names = result["chart"]["planets"].map { |p| p["planet"] }

      expect(planet_names).to eq(
        %w[太陽 月亮 水星 金星 火星 木星 土星 天王星 海王星 冥王星 北交點 南交點
           福點 莉莉絲 北交點定位星 南交點定位星 上升星座定位星]
      )
    end

    it "includes ruler points (定位星)" do
      planets = result["chart"]["planets"]
      ruler_names = planets.map { |p| p["planet"] }

      expect(ruler_names).to include("北交點定位星")
      expect(ruler_names).to include("南交點定位星")
      expect(ruler_names).to include("上升星座定位星")
    end

    it "flags retrograde on every planet entry" do
      planets = result["chart"]["planets"]

      planets.each do |p|
        expect([true, false]).to include(p["retrograde"]),
          "#{p["planet"]} has no boolean retrograde flag"
      end
    end

    it "never marks 太陽/月亮/福點/莉莉絲/定位星 retrograde" do
      planets = result["chart"]["planets"]

      %w[太陽 月亮 福點 莉莉絲 北交點定位星 南交點定位星 上升星座定位星].each do |name|
        entry = planets.find { |p| p["planet"] == name }
        expect(entry["retrograde"]).to be(false), "#{name} should be hard-false"
      end
    end

    it "mirrors 北交點's retrograde flag on 南交點" do
      planets = result["chart"]["planets"]
      nn = planets.find { |p| p["planet"] == "北交點" }
      sn = planets.find { |p| p["planet"] == "南交點" }

      expect(sn["retrograde"]).to eq(nn["retrograde"])
    end

    it "marks 水星/金星/木星 retrograde on 1990-01-01 (known retrograde windows)" do
      planets = result["chart"]["planets"]

      %w[水星 金星 木星].each do |name|
        entry = planets.find { |p| p["planet"] == name }
        expect(entry["retrograde"]).to be(true), "#{name} was retrograde on 1990-01-01"
      end
    end

    it "shapes 福點 and 莉莉絲 like regular planet entries" do
      planets = result["chart"]["planets"]

      %w[福點 莉莉絲].each do |name|
        entry = planets.find { |p| p["planet"] == name }
        expect(entry).not_to be_nil
        expect(AstroChart::Zodiac::SIGNS).to include(entry["zodiac"])
        expect(entry["house"]).to be_between(1, 12)
        expect(entry["degree"]).to be_between(0, 30)
        expect(entry["total_degree"]).to be_between(0, 360)
        expect(entry["retrograde"]).to be(false)
      end
    end

    it "computes 福點 from the day/night formula" do
      planets = result["chart"]["planets"]
      asc  = result["chart"]["ascendant"]["total_degree"]
      sun  = planets.find { |p| p["planet"] == "太陽" }["total_degree"]
      moon = planets.find { |p| p["planet"] == "月亮" }["total_degree"]
      fortune = planets.find { |p| p["planet"] == "福點" }["total_degree"]

      day   = (asc + moon - sun) % 360.0
      night = (asc - moon + sun) % 360.0
      expect(fortune).to be_within(0.001).of(day).or be_within(0.001).of(night)
    end

    it "includes house_system, patterns and element_stats" do
      chart = result["chart"]

      expect(chart["house_system"]).to eq("P")
      expect(chart["patterns"]).to be_an(Array)
      chart["patterns"].each do |pattern|
        expect(%w[大三角 T三角 大十字]).to include(pattern["pattern_type"])
      end

      stats = chart["element_stats"]
      expect(stats["elements"].keys).to eq(%w[火 土 風 水])
      expect(stats["modalities"].keys).to eq(%w[基本 固定 變動])
      # 10 classical planets feed the counts
      expect(stats["elements"].values.sum).to eq(10)
      expect(stats["modalities"].values.sum).to eq(10)
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

  describe "house_system option" do
    let(:base_args) do
      {
        birth_date: "1990-01-01",
        birth_time: "12:00",
        latitude: 25.0330,
        longitude: 121.5654,
        timezone: "Asia/Taipei",
      }
    end

    it "defaults to Placidus" do
      expect(described_class.new(**base_args).house_system).to eq("P")
    end

    it "raises ArgumentError for unknown systems" do
      expect { described_class.new(**base_args, house_system: "K") }
        .to raise_error(ArgumentError, /house system/)
      expect { described_class.new(**base_args, house_system: "X") }
        .to raise_error(ArgumentError)
    end

    context "with whole-sign houses" do
      subject(:result) { described_class.new(**base_args, house_system: "W").generate }

      it "reports house_system W" do
        expect(result["chart"]["house_system"]).to eq("W")
      end

      it "puts every cusp on a sign boundary, starting at the ascendant's sign" do
        cusps = result["chart"]["houses"].map { |h| h["degree"] }
        expect(cusps.length).to eq(12)
        cusps.each { |deg| expect(deg % 30).to eq(0.0) }

        asc = result["chart"]["ascendant"]["total_degree"]
        expect(cusps[0]).to eq((asc / 30).floor * 30.0)
      end

      it "keeps the ascendant identical to the Placidus chart" do
        placidus = described_class.new(**base_args).generate
        expect(result["chart"]["ascendant"]).to eq(placidus["chart"]["ascendant"])
      end

      it "keeps the same 17 planet entries" do
        expect(result["chart"]["planets"].length).to eq(17)
      end

      it "keeps 福點 identical to the Placidus chart (sect is horizon-based)" do
        # Sect is an astronomical fact — the display house system must not
        # change 福點. Regression: this birth instant has the Sun below the
        # horizon but in whole-sign house 7, which used to flip the formula.
        args = {
          birth_date: "1997-05-26",
          birth_time: "22:03",
          latitude: 52.6,
          longitude: -15.99,
          timezone: "UTC",
        }
        fortune = lambda do |hs|
          chart = described_class.new(**args, house_system: hs).generate
          chart["chart"]["planets"].find { |p| p["planet"] == "福點" }["total_degree"]
        end

        expect(fortune.call("W")).to eq(fortune.call("P"))
        expect(fortune.call("P")).to be_within(0.01).of(18.7565) # night formula
      end
    end
  end

  describe "ephemeris range edges" do
    it "generates charts within half a day of the Pluto series' lower bound" do
      result = described_class.new(
        birth_date: "1885-01-01",
        birth_time: "06:00",
        latitude: 25.0,
        longitude: 121.5,
        timezone: "UTC"
      ).generate

      pluto = result["chart"]["planets"].find { |p| p["planet"] == "冥王星" }
      expect(pluto["total_degree"]).to be_between(0, 360)
      expect([true, false]).to include(pluto["retrograde"])
    end

    it "generates charts within half a day of the Pluto series' upper bound" do
      result = described_class.new(
        birth_date: "2099-12-31",
        birth_time: "20:00",
        latitude: 25.0,
        longitude: 121.5,
        timezone: "UTC"
      ).generate

      pluto = result["chart"]["planets"].find { |p| p["planet"] == "冥王星" }
      expect(pluto["total_degree"]).to be_between(0, 360)
      expect([true, false]).to include(pluto["retrograde"])
    end
  end
end
