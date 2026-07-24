require "spec_helper"

RSpec.describe AstroChart::Synastry do
  describe ".cross_aspects" do
    it "finds aspects between two position sets" do
      a = { "太陽" => 10.0 }
      b = { "月亮" => 130.0 } # 120° apart => trine

      results = described_class.cross_aspects(a, b)

      expect(results.length).to eq(1)
      expect(results.first).to include(
        "a_planet"    => "太陽",
        "b_planet"    => "月亮",
        "aspect_type" => "三分相",
        "orb"         => 0.0
      )
    end

    it "keeps both directions as distinct pairs" do
      a = { "太陽" => 10.0, "月亮" => 100.0 }
      b = { "太陽" => 100.0, "月亮" => 10.0 }

      results = described_class.cross_aspects(a, b)
      pairs = results.map { |r| [r["a_planet"], r["b_planet"]] }

      # A太陽(10)×B月亮(10) 合相、A月亮(100)×B太陽(100) 合相，
      # A太陽(10)×B太陽(100) 90° 四分相、A月亮(100)×B月亮(10) 四分相
      expect(pairs).to include(%w[太陽 月亮], %w[月亮 太陽], %w[太陽 太陽], %w[月亮 月亮])
    end

    it "handles the 0/360 wrap-around" do
      a = { "太陽" => 359.0 }
      b = { "月亮" => 1.0 } # 2° apart => conjunction

      results = described_class.cross_aspects(a, b)

      expect(results.first["aspect_type"]).to eq("合相")
      expect(results.first["orb"]).to eq(2.0)
    end

    it "filters by orb_limit when given" do
      a = { "太陽" => 10.0 }
      b = { "月亮" => 24.0 } # conjunction with orb 14 (within default 15)

      expect(described_class.cross_aspects(a, b).length).to eq(1)
      expect(described_class.cross_aspects(a, b, orb_limit: 6.0)).to be_empty
    end

    it "sorts results by orb (tightest first)" do
      a = { "太陽" => 10.0, "金星" => 15.0 }
      b = { "月亮" => 11.0 }

      results = described_class.cross_aspects(a, b)

      expect(results.first["a_planet"]).to eq("太陽") # orb 1 before orb 4
      expect(results.map { |r| r["orb"] }).to eq(results.map { |r| r["orb"] }.sort)
    end

    it "returns empty when nothing aspects" do
      a = { "太陽" => 0.0 }
      b = { "月亮" => 40.0 } # 40°: no major aspect

      expect(described_class.cross_aspects(a, b)).to be_empty
    end
  end

  describe ".house_overlay" do
    let(:equal_cusps) { (0...12).map { |i| i * 30.0 } }

    it "places planets into the other chart's houses" do
      positions = { "太陽" => 45.0, "月亮" => 359.9 }

      overlay = described_class.house_overlay(positions, equal_cusps)

      expect(overlay["太陽"]).to eq(2)
      expect(overlay["月亮"]).to eq(12)
    end

    it "handles cusps that wrap 0°" do
      cusps = (0...12).map { |i| (300.0 + i * 30.0) % 360.0 } # 1st house starts at 300°
      overlay = described_class.house_overlay({ "太陽" => 310.0, "火星" => 10.0 }, cusps)

      expect(overlay["太陽"]).to eq(1)
      expect(overlay["火星"]).to eq(3)
    end
  end

  describe ".between (integration with Chart)" do
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

    it "returns cross aspects between real charts" do
      expect(result["aspects"]).not_to be_empty
      result["aspects"].each do |aspect|
        expect(AstroChart::Synastry::BODIES).to include(aspect["a_planet"])
        expect(AstroChart::Synastry::BODIES).to include(aspect["b_planet"])
        expect(aspect["orb"]).to be >= 0
      end
    end

    it "places each person's planets in the other's houses" do
      expect(result["a_planets_in_b_houses"].keys).to match_array(AstroChart::Synastry::BODIES)
      expect(result["b_planets_in_a_houses"].keys).to match_array(AstroChart::Synastry::BODIES)
      result["a_planets_in_b_houses"].each_value { |h| expect(h).to be_between(1, 12) }
    end

    it "excludes 南交點 and ruler points from comparison" do
      names = result["aspects"].flat_map { |a| [a["a_planet"], a["b_planet"]] }.uniq
      expect(names).not_to include("南交點")
    end

    it "is symmetric: swapping charts mirrors the aspect pairs" do
      swapped = described_class.between(chart_b, chart_a)

      forward = result["aspects"].map { |x| [x["a_planet"], x["b_planet"], x["aspect_type"]] }.sort
      mirrored = swapped["aspects"].map { |x| [x["b_planet"], x["a_planet"], x["aspect_type"]] }.sort

      expect(forward).to eq(mirrored)
    end

    it "respects orb_limit" do
      tight = described_class.between(chart_a, chart_b, orb_limit: 3.0)
      expect(tight["aspects"].length).to be <= result["aspects"].length
      tight["aspects"].each { |a| expect(a["orb"]).to be <= 3.0 }
    end

    it "raises on chart hash without planets" do
      expect { described_class.between({}, chart_b) }.to raise_error(ArgumentError, /planets/)
    end
  end

  describe ".positions_from_chart fallback" do
    it "reconstructs total degree from zodiac + in-sign degree when total_degree missing" do
      chart = {
        "chart" => {
          "planets" => [{ "planet" => "太陽", "zodiac" => "巨蟹座", "degree" => 11.3375 }],
          "houses" => (0...12).map { |i| { "house_number" => i + 1, "degree" => i * 30.0 } },
        },
      }

      positions = described_class.positions_from_chart(chart)

      expect(positions["太陽"]).to be_within(0.0001).of(101.3375) # 巨蟹 = 90° + 11.3375
    end
  end
end
