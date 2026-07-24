require "spec_helper"
require "astro_chart/composite"

RSpec.describe AstroChart::Composite do
  def chart_with(positions)
    {
      "chart" => {
        "planets" => positions.map do |name, deg|
          {
            "planet"       => name,
            "zodiac"       => AstroChart::Zodiac.sign_name(deg),
            "degree"       => (deg % 30).round(4),
            "total_degree" => deg,
          }
        end,
      },
    }
  end

  describe ".midpoint" do
    it "returns the plain midpoint for nearby longitudes" do
      expect(described_class.midpoint(10.0, 50.0)).to eq(30.0)
      expect(described_class.midpoint(100.0, 200.0)).to eq(150.0)
    end

    it "is symmetric" do
      expect(described_class.midpoint(50.0, 10.0)).to eq(30.0)
    end

    it "takes the shorter arc across 0°: 350° & 10° => 0°, not 180°" do
      expect(described_class.midpoint(350.0, 10.0)).to eq(0.0)
      expect(described_class.midpoint(10.0, 350.0)).to eq(0.0)
    end

    it "handles another wrap-around case" do
      expect(described_class.midpoint(340.0, 20.0)).to eq(0.0)
      expect(described_class.midpoint(300.0, 40.0)).to eq(350.0)
    end

    it "returns the input when both positions coincide" do
      expect(described_class.midpoint(123.45, 123.45)).to eq(123.45)
    end
  end

  describe ".between" do
    it "computes midpoint positions for bodies present in both charts" do
      a = chart_with("太陽" => 10.0, "月亮" => 100.0)
      b = chart_with("太陽" => 20.0, "月亮" => 120.0)

      result = described_class.between(a, b)
      sun = result["planets"].find { |p| p["planet"] == "太陽" }
      moon = result["planets"].find { |p| p["planet"] == "月亮" }

      expect(sun).to include(
        "zodiac"       => "牡羊座",
        "degree"       => 15.0,
        "total_degree" => 15.0
      )
      expect(moon).to include(
        "zodiac"       => "巨蟹座",
        "degree"       => 20.0,
        "total_degree" => 110.0
      )
    end

    it "places a wrap-around composite Sun at 0° 牡羊座" do
      a = chart_with("太陽" => 350.0)
      b = chart_with("太陽" => 10.0)

      sun = described_class.between(a, b)["planets"].first

      expect(sun["total_degree"]).to eq(0.0)
      expect(sun["zodiac"]).to eq("牡羊座")
    end

    it "skips bodies missing from either chart" do
      a = chart_with("太陽" => 10.0, "月亮" => 100.0)
      b = chart_with("太陽" => 20.0)

      names = described_class.between(a, b)["planets"].map { |p| p["planet"] }

      expect(names).to eq(["太陽"])
    end

    it "ignores ruler points and unknown bodies" do
      a = chart_with("太陽" => 10.0)
      a["chart"]["planets"] << {
        "planet" => "上升星座定位星", "total_degree" => 33.3
      }
      b = chart_with("太陽" => 20.0, "上升星座定位星" => 44.4)

      names = described_class.between(a, b)["planets"].map { |p| p["planet"] }

      expect(names).to eq(["太陽"])
    end

    it "computes aspects among the composite positions, sorted by orb" do
      # composites: 太陽 15°, 月亮 110°, 金星 16° => 太陽合金星 (orb 1),
      # 太陽四分月亮 (orb 5), 月亮四分金星 (orb 6)
      a = chart_with("太陽" => 10.0, "月亮" => 100.0, "金星" => 12.0)
      b = chart_with("太陽" => 20.0, "月亮" => 120.0, "金星" => 20.0)

      aspects = described_class.between(a, b)["aspects"]

      expect(aspects.map { |x| x["orb"] }).to eq(aspects.map { |x| x["orb"] }.sort)
      expect(aspects.first).to include(
        "planet_a"    => "太陽",
        "planet_b"    => "金星",
        "aspect_type" => "合相",
        "orb"         => 1.0
      )
      square = aspects.find { |x| [x["planet_a"], x["planet_b"]].sort == %w[太陽 月亮].sort }
      expect(square).to include("aspect_type" => "四分相", "orb" => 5.0)
    end

    it "does not pair a body with itself or duplicate reversed pairs" do
      a = chart_with("太陽" => 10.0, "月亮" => 130.0)
      b = chart_with("太陽" => 10.0, "月亮" => 130.0)

      aspects = described_class.between(a, b)["aspects"]

      pairs = aspects.map { |x| [x["planet_a"], x["planet_b"]].sort }
      expect(pairs).to eq(pairs.uniq)
      aspects.each { |x| expect(x["planet_a"]).not_to eq(x["planet_b"]) }
    end

    it "raises on a chart hash without planets" do
      expect { described_class.between({}, chart_with("太陽" => 1.0)) }
        .to raise_error(ArgumentError, /planets/)
    end

    context "with real Chart#generate results" do
      let(:chart_a) do
        AstroChart::Chart.new(
          birth_date: "1988-07-03", birth_time: "09:20",
          latitude: 22.6273, longitude: 120.3014, timezone: "Asia/Taipei"
        ).generate
      end

      let(:chart_b) do
        AstroChart::Chart.new(
          birth_date: "1991-08-11", birth_time: "06:30",
          latitude: 25.0120, longitude: 121.4657, timezone: "Asia/Taipei"
        ).generate
      end

      let(:result) { described_class.between(chart_a, chart_b) }

      it "returns all 12 bodies" do
        expect(result["planets"].map { |p| p["planet"] })
          .to match_array(AstroChart::Composite::BODIES)
      end

      it "returns valid zodiac/degree fields" do
        result["planets"].each do |p|
          expect(AstroChart::Zodiac::SIGNS).to include(p["zodiac"])
          expect(p["degree"]).to be_between(0, 30)
          expect(p["total_degree"]).to be_between(0, 360)
        end
      end

      it "keeps each composite position on the shorter arc between the natal pair" do
        pos_a = described_class.positions_from_chart(chart_a)
        pos_b = described_class.positions_from_chart(chart_b)

        result["planets"].each do |p|
          a = pos_a[p["planet"]]
          b = pos_b[p["planet"]]
          half_arc = (((b - a + 540.0) % 360.0 - 180.0) / 2.0).abs
          dist_to_a = ((p["total_degree"] - a + 540.0) % 360.0 - 180.0).abs
          expect(dist_to_a).to be_within(0.001).of(half_arc)
        end
      end

      it "keeps composite 南交點 opposite composite 北交點" do
        nn = result["planets"].find { |p| p["planet"] == "北交點" }["total_degree"]
        sn = result["planets"].find { |p| p["planet"] == "南交點" }["total_degree"]

        expect((nn - sn).abs % 360.0).to be_within(0.001).of(180.0)
      end

      it "does not include houses (out of scope for midpoint composites)" do
        expect(result.keys).to match_array(%w[planets aspects])
      end
    end
  end
end
