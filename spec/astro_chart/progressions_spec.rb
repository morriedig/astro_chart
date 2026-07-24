require "spec_helper"
require "astro_chart/progressions"

RSpec.describe AstroChart::Progressions do
  # UTC natal chart so day counts between dates are exact calendar days.
  let(:natal_chart) do
    AstroChart::Chart.new(
      birth_date: "1990-01-01", birth_time: "12:00",
      latitude: 0.0, longitude: 0.0, timezone: "UTC"
    ).generate
  end

  let(:jd_natal) { AstroChart::TimeConversion.to_julian_day("1990-01-01", "12:00", "UTC") }

  describe ".secondary date math (a day for a year)" do
    it "hand-checked 30-year example: ~30 days are added to jd_natal" do
      result = described_class.secondary(natal_chart, "2020-01-01")

      # 1990-01-01 → 2020-01-01 spans 10957 days (7 leap years in between),
      # i.e. 10957 / 365.2425 = 29.999247 years → jd_prog = jd_natal + 29.999247
      expect(result["years_elapsed"]).to eq(30.0)
      expect(result["progressed_jd"] - jd_natal).to be_within(1e-6).of(10_957 / 365.2425)
    end

    it "one year elapsed adds ~1 day and moves the Sun ~1 degree" do
      result = described_class.secondary(natal_chart, "1991-01-01")

      expect(result["years_elapsed"]).to eq(1.0)
      expect(result["progressed_jd"] - jd_natal).to be_within(0.001).of(1.0) # 365/365.2425

      natal_sun = natal_chart["chart"]["planets"].find { |p| p["planet"] == "太陽" }["total_degree"]
      prog_sun  = result["planets"].find { |p| p["planet"] == "太陽" }["total_degree"]
      moved = (prog_sun - natal_sun) % 360.0
      expect(moved).to be_between(0.9, 1.1) # daily solar motion near perihelion
    end

    it "target date == birth date reproduces the natal positions" do
      result = described_class.secondary(natal_chart, "1990-01-01")

      expect(result["years_elapsed"]).to eq(0.0)
      expect(result["progressed_jd"]).to eq(jd_natal)

      natal_by_name = natal_chart["chart"]["planets"]
                      .select { |p| p["total_degree"] && p["ruling_planet"].nil? }
                      .to_h { |p| [p["planet"], p["total_degree"]] }

      result["planets"].each do |p|
        expect(p["total_degree"]).to be_within(0.001).of(natal_by_name[p["planet"]])
      end
    end

    it "handles a target before birth with negative years" do
      result = described_class.secondary(natal_chart, "1989-01-01")

      expect(result["years_elapsed"]).to eq(-1.0)
      expect(result["progressed_jd"]).to be < jd_natal
    end
  end

  describe ".secondary output shape" do
    let(:result) { described_class.secondary(natal_chart, "2020-01-01") }

    it "lists all 12 progressed bodies with natal house placement" do
      expect(result["planets"].length).to eq(12)
      names = result["planets"].map { |p| p["planet"] }
      expect(names).to match_array(AstroChart::Ephemeris::PLANETS.keys + ["南交點"])

      cusps = AstroChart::Synastry.cusps_from_chart(natal_chart)
      result["planets"].each do |p|
        expect(p.keys).to match_array(%w[planet zodiac degree total_degree natal_house])
        expect(p["natal_house"]).to eq(AstroChart::Houses.find_house(p["total_degree"], cusps))
        expect(AstroChart::Zodiac::SIGNS).to include(p["zodiac"])
      end
    end

    it "returns progressed-to-natal aspects within the default 1° orb, sorted" do
      orbs = result["aspects_to_natal"].map { |a| a["orb"] }
      expect(orbs).to eq(orbs.sort)

      result["aspects_to_natal"].each do |a|
        expect(a.keys).to match_array(%w[progressed_planet natal_planet aspect_type orb])
        expect(a["orb"]).to be <= 1.0
        expect(AstroChart::Synastry::BODIES).to include(a["progressed_planet"])
        expect(AstroChart::Synastry::BODIES).to include(a["natal_planet"])
      end
    end

    it "finds exact self-conjunctions when zero time has elapsed" do
      same_day = described_class.secondary(natal_chart, "1990-01-01")
      self_conjunctions = same_day["aspects_to_natal"].select do |a|
        a["progressed_planet"] == a["natal_planet"]
      end

      expect(self_conjunctions.length).to eq(AstroChart::Synastry::BODIES.length)
      self_conjunctions.each do |a|
        expect(a["aspect_type"]).to eq("合相")
        expect(a["orb"]).to be <= 0.01
      end
    end

    it "respects a custom orb_limit" do
      wide = described_class.secondary(natal_chart, "2020-01-01", orb_limit: 3.0)
      expect(wide["aspects_to_natal"].length).to be >= result["aspects_to_natal"].length
      wide["aspects_to_natal"].each { |a| expect(a["orb"]).to be <= 3.0 }
    end
  end

  describe "input validation" do
    it "raises on a chart hash without an input block" do
      expect { described_class.secondary({}, "2020-01-01") }
        .to raise_error(ArgumentError, /input/)
    end

    it "raises on an input block missing the timezone" do
      broken = { "input" => { "birth_date" => "1990-01-01", "birth_time" => "12:00" } }
      expect { described_class.secondary(broken, "2020-01-01") }
        .to raise_error(ArgumentError, /input/)
    end
  end
end
