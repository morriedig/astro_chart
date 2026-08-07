require "spec_helper"

RSpec.describe AstroChart::FixedStars do
  let(:jd2024) { AstroChart::Ephemeris.julday(2024, 1, 1, 0.0) }

  def star(name)
    AstroChart::Pure::FixedStarsData::STARS.find { |s| s[:name] == name }
  end

  def lon(name, jd = jd2024)
    described_class.ecliptic_longitude(star(name), jd)
  end

  it "catalogues 57 stars with the expected fields" do
    stars = AstroChart::Pure::FixedStarsData::STARS
    expect(stars.length).to eq(57)
    expect(stars.first.keys).to include(:name, :ra, :dec, :pm_ra, :pm_dec, :vmag, :nature, :keyword)
    expect(stars.map { |s| s[:name] }).to include("Regulus", "Algol", "Spica", "Antares", "Aldebaran")
  end

  # Known modern ecliptic longitudes (tropical) of the royal/notable stars.
  it "matches published fixed-star longitudes for 2024" do
    expect(lon("Regulus")).to be_within(0.3).of(150.16)  # ~0° Virgo
    expect(lon("Spica")).to be_within(0.3).of(204.18)    # ~24° Libra
    expect(lon("Antares")).to be_within(0.3).of(250.1)   # ~10° Sagittarius
    expect(lon("Aldebaran")).to be_within(0.3).of(70.1)  # ~10° Gemini
    expect(lon("Algol")).to be_within(0.3).of(56.5)      # ~26° Taurus
    expect(lon("Sirius")).to be_within(0.3).of(104.4)    # ~14° Cancer
  end

  it "precesses ~50.3″/yr (Regulus moves ~1° over 72 years)" do
    jd1952 = AstroChart::Ephemeris.julday(1952, 1, 1, 0.0)
    delta = described_class.separation(lon("Regulus", jd2024), lon("Regulus", jd1952))
    expect(delta).to be_within(0.05).of(72 * 50.29 / 3600.0) # ~1.006°
  end

  describe ".conjunctions" do
    it "finds a body conjunct a star within orb, sorted by orb, with metadata" do
      # Place a body exactly on Regulus' 2024 longitude, another 0.4° off Spica.
      positions = {
        "太陽" => lon("Regulus"),
        "火星" => lon("Spica") + 0.4,
        "月亮" => lon("Regulus") + 5.0, # outside orb
      }
      result = described_class.conjunctions(positions, jd2024, orb: 1.0)
      pairs = result.map { |r| [r["planet"], r["star"]] }
      expect(pairs).to include(["太陽", "Regulus"], ["火星", "Spica"])
      expect(pairs).not_to include(["月亮", "Regulus"])

      regulus = result.find { |r| r["star"] == "Regulus" }
      expect(regulus["orb"]).to be_within(0.01).of(0.0)
      expect(regulus).to include("nature", "keyword")
      expect(result.map { |r| r["orb"] }).to eq(result.map { |r| r["orb"] }.sort)
    end

    it "returns nothing when no body is near a star" do
      expect(described_class.conjunctions({ "太陽" => 12.34 }, jd2024, orb: 0.1)).to be_empty
    end
  end
end
