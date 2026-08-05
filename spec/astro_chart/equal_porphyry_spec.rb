require "spec_helper"

# Equal ("E") and Porphyry ("O") house systems on the pure backend.
RSpec.describe "Equal and Porphyry house systems" do
  # 1990-01-01 12:00 Asia/Taipei, Taipei — a mid-latitude chart.
  let(:jd) { AstroChart::TimeConversion.to_julian_day("1990-01-01", "12:00", "Asia/Taipei") }
  let(:lat) { 25.033 }
  let(:lon) { 121.5654 }

  def norm(x) = x % 360.0

  describe "Equal (\"E\")" do
    subject(:h) { AstroChart::Ephemeris.houses(jd, lat, lon, "E") }

    it "puts cusp 1 on the ascendant and steps 30° per house" do
      asc = h["ascendant"]
      h["cusps"].each_with_index do |cusp, i|
        expect(cusp).to be_within(1e-9).of(norm(asc + 30.0 * i))
      end
    end

    it "keeps the true MC even though it is not the 10th cusp" do
      p = AstroChart::Ephemeris.houses(jd, lat, lon, "P")
      expect(h["mc"]).to be_within(1e-9).of(p["mc"])
      # 10th equal cusp is ASC+270, generally not the MC
      expect((h["cusps"][9] - h["mc"]).abs).to be > 1.0
    end
  end

  describe "Porphyry (\"O\")" do
    subject(:h) { AstroChart::Ephemeris.houses(jd, lat, lon, "O") }

    it "shares the four angles with Placidus" do
      p = AstroChart::Ephemeris.houses(jd, lat, lon, "P")
      [0, 3, 6, 9].each do |i|
        expect(h["cusps"][i]).to be_within(1e-9).of(p["cusps"][i])
      end
    end

    it "trisects each quadrant between the angles" do
      c = h["cusps"]
      quadrants = [[0, 1, 2, 3], [3, 4, 5, 6], [6, 7, 8, 9], [9, 10, 11, 0]]
      quadrants.each do |a, m1, m2, b|
        arc = norm(c[b] - c[a])
        expect(norm(c[m1] - c[a])).to be_within(1e-6).of(arc / 3.0)
        expect(norm(c[m2] - c[a])).to be_within(1e-6).of(2.0 * arc / 3.0)
      end
    end

    it "places opposite cusps exactly 180° apart" do
      c = h["cusps"]
      6.times do |i|
        expect(norm(c[i + 6] - c[i])).to be_within(1e-9).of(180.0)
      end
    end
  end

  describe "polar robustness" do
    # Inside the polar circle Placidus is undefined; Equal and Porphyry
    # are defined wherever the ascendant is (|lat| < 90°).
    let(:polar_lat) { 78.0 }
    let(:polar_lon) { 15.0 }

    it "Placidus raises but Equal and Porphyry do not" do
      expect { AstroChart::Ephemeris.houses(jd, polar_lat, polar_lon, "P") }
        .to raise_error(AstroChart::Pure::Core::DomainError)

      %w[E O].each do |sys|
        expect { AstroChart::Ephemeris.houses(jd, polar_lat, polar_lon, sys) }
          .not_to raise_error
      end
    end
  end

  describe "dispatch and validation" do
    it "accepts the ord aliases 69 (E) and 79 (O)" do
      by_letter = AstroChart::Pure.houses(jd, lat, lon, "E")
      by_ord    = AstroChart::Pure.houses(jd, lat, lon, 69)
      expect(by_ord["cusps"]).to eq(by_letter["cusps"])

      o_letter = AstroChart::Pure.houses(jd, lat, lon, "O")
      o_ord    = AstroChart::Pure.houses(jd, lat, lon, 79)
      expect(o_ord["cusps"]).to eq(o_letter["cusps"])
    end

    it "Chart.new accepts \"E\" and \"O\" and reports the system" do
      %w[E O].each do |sys|
        result = AstroChart::Chart.new(
          birth_date: "1990-01-01", birth_time: "12:00",
          latitude: lat, longitude: lon, timezone: "Asia/Taipei",
          house_system: sys
        ).generate
        expect(result["chart"]["house_system"]).to eq(sys)
        expect(result["chart"]["houses"].length).to eq(12)
      end
    end

    it "still rejects unknown house systems" do
      expect do
        AstroChart::Chart.new(
          birth_date: "1990-01-01", birth_time: "12:00",
          latitude: lat, longitude: lon, timezone: "Asia/Taipei",
          house_system: "K"
        )
      end.to raise_error(ArgumentError, /unknown house system/)
    end
  end
end
