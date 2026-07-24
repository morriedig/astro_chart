require "spec_helper"

RSpec.describe "Whole-sign houses" do
  # Swiss oracle is only available locally (compiled C ext); skip cleanly elsewhere.
  swiss_available =
    begin
      AstroChart.load_swiss_extension!
      true
    rescue LoadError
      false
    end

  after { AstroChart.backend = :pure }

  let(:jd) { AstroChart::Ephemeris.julday(1990, 6, 15, 8.5) }
  let(:lat) { 25.03 }
  let(:lon) { 121.56 }

  describe "AstroChart::Pure.houses with system \"W\"" do
    let(:whole) { AstroChart::Pure.houses(jd, lat, lon, "W") }
    let(:placidus) { AstroChart::Pure.houses(jd, lat, lon, "P") }

    it "returns 12 cusps" do
      expect(whole["cusps"].length).to eq(12)
    end

    it "returns cusps that are all multiples of 30 degrees" do
      whole["cusps"].each do |cusp|
        expect(cusp % 30.0).to be_within(1e-9).of(0.0)
      end
    end

    it "starts cusp 1 at the beginning of the ascendant's sign" do
      asc = whole["ascendant"]
      expect(whole["cusps"][0]).to eq((asc / 30.0).floor * 30.0)
    end

    it "spaces consecutive cusps exactly 30 degrees apart (mod 360)" do
      12.times do |i|
        expected = (whole["cusps"][0] + 30.0 * i) % 360.0
        expect(whole["cusps"][i]).to be_within(1e-9).of(expected)
      end
    end

    it "keeps ascendant and mc identical to Placidus at ordinary latitudes" do
      expect(whole["ascendant"]).to eq(placidus["ascendant"])
      expect(whole["mc"]).to eq(placidus["mc"])
    end

    it "places the ascendant inside the first house sign" do
      expect((whole["ascendant"] / 30.0).floor * 30.0).to eq(whole["cusps"][0])
    end

    it "accepts 87 (\"W\".ord) like the C extension int convention" do
      expect(AstroChart::Pure.houses(jd, lat, lon, 87)).to eq(whole)
    end

    it "still rejects unknown house systems" do
      expect { AstroChart::Pure.houses(jd, lat, lon, "K") }.to raise_error(ArgumentError, /unsupported house system/)
    end
  end

  describe "polar latitudes" do
    let(:polar_lat) { 78.2 }
    let(:polar_lon) { 15.6 }

    it "computes whole-sign houses where Placidus raises DomainError" do
      expect { AstroChart::Pure.houses(jd, polar_lat, polar_lon, "P") }
        .to raise_error(AstroChart::Pure::Core::DomainError)

      whole = AstroChart::Pure.houses(jd, polar_lat, polar_lon, "W")
      expect(whole["cusps"].length).to eq(12)
      whole["cusps"].each { |c| expect(c % 30.0).to be_within(1e-9).of(0.0) }
      expect(whole["cusps"][0]).to eq((whole["ascendant"] / 30.0).floor * 30.0)
    end

    it "keeps the ascendant on the east side of the MC inside the polar circle" do
      whole = AstroChart::Pure.houses(jd, polar_lat, polar_lon, "W")
      expect((whole["ascendant"] - whole["mc"]) % 360.0).to be < 180.0
    end
  end

  describe "AstroChart::Houses.calculate" do
    it "defaults to Placidus" do
      cusps, asc = AstroChart::Houses.calculate(jd, lat, lon)
      expect([cusps, asc]).to eq(AstroChart::Houses.calculate(jd, lat, lon, system: "P"))
    end

    it "passes system: \"W\" through to the backend" do
      cusps, asc = AstroChart::Houses.calculate(jd, lat, lon, system: "W")
      expect(cusps.length).to eq(12)
      cusps.each { |c| expect(c % 30.0).to be_within(1e-9).of(0.0) }
      expect(cusps[0]).to eq((asc / 30.0).floor * 30.0)
    end
  end

  describe "against the Swiss Ephemeris oracle", if: swiss_available do
    it "matches Swiss whole-sign cusps and ascendant across random charts" do
      srand(20_260_724)
      30.times do
        chart_jd = AstroChart::Ephemeris.julday(rand(1950..2030), rand(1..12), rand(1..28), rand * 24.0)
        chart_lat = rand * 130.0 - 65.0
        chart_lon = rand * 360.0 - 180.0

        AstroChart.backend = :pure
        pure = AstroChart::Ephemeris.houses(chart_jd, chart_lat, chart_lon, "W")
        AstroChart.backend = :swiss
        swiss = AstroChart::Ephemeris.houses(chart_jd, chart_lat, chart_lon, "W")

        asc_diff = ((pure["ascendant"] - swiss["ascendant"] + 540) % 360) - 180
        expect(asc_diff.abs).to be < 0.01

        # Cusps must agree exactly unless the ascendant sits right on a sign boundary
        boundary_dist = [pure["ascendant"] % 30.0, 30.0 - (pure["ascendant"] % 30.0)].min
        expect(pure["cusps"]).to eq(swiss["cusps"]) if boundary_dist > 0.01
      end
    end

    it "matches Swiss whole-sign ascendant inside the polar circle" do
      [[78.2, 15.6], [-75.0, -60.0], [82.5, -62.3]].each do |plat, plon|
        AstroChart.backend = :pure
        pure = AstroChart::Ephemeris.houses(jd, plat, plon, "W")
        AstroChart.backend = :swiss
        swiss = AstroChart::Ephemeris.houses(jd, plat, plon, "W")

        asc_diff = ((pure["ascendant"] - swiss["ascendant"] + 540) % 360) - 180
        expect(asc_diff.abs).to be < 0.01
        expect(pure["cusps"]).to eq(swiss["cusps"])
      end
    end
  end
end
