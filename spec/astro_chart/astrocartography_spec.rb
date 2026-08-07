require "spec_helper"

RSpec.describe AstroChart::Astrocartography do
  # 1990-01-01 12:00 UT
  let(:jd) { AstroChart::Ephemeris.julday(1990, 1, 1, 12.0) }
  let(:result) { described_class.lines(jd) }

  Core = AstroChart::Pure::Core
  D2R = Core::DEG2RAD

  def gst_for(jd) = Core.apparent_sidereal_deg(jd)

  # Equatorial coords the module uses (with the body's true ecliptic latitude),
  # for independent checks.
  def ra_dec(jd, name)
    eps = Core.true_obliquity(Core.jd_tt(jd)) * D2R
    lam_d, beta_d = AstroChart::Ephemeris.ecliptic_latlon(jd, AstroChart::Ephemeris::PLANETS[name])
    lam = lam_d * D2R
    beta = beta_d * D2R
    ra = Core.norm360(Math.atan2(
      Math.sin(lam) * Math.cos(eps) - Math.tan(beta) * Math.sin(eps), Math.cos(lam)
    ) * (180.0 / Math::PI))
    dec = Math.asin(Math.sin(beta) * Math.cos(eps) + Math.cos(beta) * Math.sin(eps) * Math.sin(lam))
    [ra, dec]
  end

  it "uses the body's real ecliptic latitude (Moon and Pluto are non-zero)" do
    _, moon_beta = AstroChart::Ephemeris.ecliptic_latlon(jd, AstroChart::Ephemeris::PLANETS["月亮"])
    _, pluto_beta = AstroChart::Ephemeris.ecliptic_latlon(jd, AstroChart::Ephemeris::PLANETS["冥王星"])
    expect(moon_beta.abs).to be > 0.5
    expect(pluto_beta.abs).to be > 0.5
  end

  # Apparent altitude (degrees) of a body at geographic (lat, lon).
  def altitude(jd, name, lat, lon)
    ra, dec = ra_dec(jd, name)
    lst = Core.norm360(gst_for(jd) + lon)     # local sidereal time (deg)
    h = (lst - ra) * D2R                        # hour angle
    phi = lat * D2R
    Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(h)) / D2R
  end

  it "returns the ten bodies, each with mc/ic/asc/dsc" do
    expect(result.length).to eq(10)
    expect(result.map { |r| r["planet"] }).to include("太陽", "月亮", "冥王星")
    result.each do |r|
      expect(r).to include("mc", "ic", "asc", "dsc")
      expect(r["mc"]).to be_between(-180, 180)
      expect(r["asc"]).to be_an(Array)
    end
  end

  it "places the MC longitude where local sidereal time equals the body's RA" do
    result.each do |r|
      ra, = ra_dec(jd, r["planet"])
      lst = Core.norm360(gst_for(jd) + r["mc"])
      diff = (lst - ra) % 360.0
      diff = 360.0 - diff if diff > 180.0
      expect(diff).to be < 1e-6
    end
  end

  it "puts the IC exactly 180° from the MC" do
    result.each do |r|
      sep = (r["ic"] - r["mc"]) % 360.0
      expect([sep, 360.0 - sep].min).to be_within(1e-6).of(180.0)
    end
  end

  it "has the body on the horizon (altitude ≈ 0) along every ASC/DSC point" do
    result.each do |r|
      (r["asc"] + r["dsc"]).each do |segment|
        segment.each do |(lat, lon)|
          expect(altitude(jd, r["planet"], lat, lon).abs).to be < 1e-6
        end
      end
    end
  end

  it "breaks the horizon curve where the body is circumpolar" do
    # The Sun (δ ≈ −23° near the solstice) never rises inside the deep south
    # polar region, so its ASC curve should not span the full latitude range.
    sun = result.find { |r| r["planet"] == "太陽" }
    covered = (sun["asc"] + sun["dsc"]).flatten(1).map { |(lat, _)| lat }
    expect(covered.min).to be > described_class::LAT_MIN
  end
end
