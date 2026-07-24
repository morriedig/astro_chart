require "spec_helper"
require "astro_chart/points"

RSpec.describe AstroChart::Points do
  describe ".fortune" do
    it "uses ASC + Moon - Sun for a day chart" do
      # 100 + 50 - 280 = -130 -> 230
      expect(described_class.fortune(asc: 100.0, sun: 280.0, moon: 50.0, day_chart: true))
        .to be_within(1e-9).of(230.0)
    end

    it "uses ASC - Moon + Sun for a night chart" do
      # 100 - 50 + 280 = 330
      expect(described_class.fortune(asc: 100.0, sun: 280.0, moon: 50.0, day_chart: false))
        .to be_within(1e-9).of(330.0)
    end

    it "wraps results above 360 back into range" do
      # 350 + 340 - 10 = 680 -> 320
      expect(described_class.fortune(asc: 350.0, sun: 10.0, moon: 340.0, day_chart: true))
        .to be_within(1e-9).of(320.0)
    end

    it "equals the ascendant when Sun and Moon are conjunct" do
      expect(described_class.fortune(asc: 123.4, sun: 77.7, moon: 77.7, day_chart: true))
        .to be_within(1e-9).of(123.4)
      expect(described_class.fortune(asc: 123.4, sun: 77.7, moon: 77.7, day_chart: false))
        .to be_within(1e-9).of(123.4)
    end

    it "always returns a longitude in [0, 360) and day/night formulas mirror around the ASC" do
      rng = Random.new(42)
      100.times do
        asc  = rng.rand(360.0)
        sun  = rng.rand(360.0)
        moon = rng.rand(360.0)

        day   = described_class.fortune(asc: asc, sun: sun, moon: moon, day_chart: true)
        night = described_class.fortune(asc: asc, sun: sun, moon: moon, day_chart: false)

        [day, night].each do |lon|
          expect(lon).to be >= 0.0
          expect(lon).to be < 360.0
        end

        # Day and night results are reflections of each other through the ASC:
        # day - asc == asc - night (mod 360)
        residue = ((day - asc) - (asc - night)) % 360.0
        expect([residue, 360.0 - residue].min).to be_within(1e-9).of(0.0)

        # Formulas differ whenever Sun and Moon are not conjunct/opposed twice over
        expect(day).not_to eq(night) unless ((moon - sun) * 2) % 360.0 == 0.0
      end
    end
  end

  describe ".day_chart?" do
    let(:cusps) do
      [10.0, 40.0, 70.0, 100.0, 130.0, 160.0, 190.0, 220.0, 250.0, 280.0, 310.0, 340.0]
    end

    it "returns true when the Sun is in houses 7-12" do
      expect(described_class.day_chart?(200.0, cusps)).to be true  # house 7
      expect(described_class.day_chart?(350.0, cusps)).to be true  # house 12
    end

    it "returns false when the Sun is in houses 1-6" do
      expect(described_class.day_chart?(20.0, cusps)).to be false  # house 1
      expect(described_class.day_chart?(185.0, cusps)).to be false # house 6
    end

    it "returns nil when the Sun cannot be placed" do
      expect(described_class.day_chart?(nil, cusps)).to be_nil
      expect(described_class.day_chart?(100.0, [])).to be_nil
    end

    context "with real ephemeris data (pure backend)" do
      it "detects a noon birth in Taipei as a day chart" do
        jd = AstroChart::Ephemeris.julday(2024, 6, 1, 4.0) # 12:00 local (UTC+8)
        cusps, = AstroChart::Houses.calculate(jd, 25.03, 121.5)
        sun = AstroChart::Ephemeris.calc_ut(jd, 0)
        expect(described_class.day_chart?(sun, cusps)).to be true
      end

      it "detects a midnight birth in Taipei as a night chart" do
        jd = AstroChart::Ephemeris.julday(2024, 5, 31, 16.0) # 00:00 local (UTC+8)
        cusps, = AstroChart::Houses.calculate(jd, 25.03, 121.5)
        sun = AstroChart::Ephemeris.calc_ut(jd, 0)
        expect(described_class.day_chart?(sun, cusps)).to be false
      end
    end
  end

  describe ".day_chart_from_horizon?" do
    it "returns true when the Sun is in the above-horizon half (DSC forward to ASC)" do
      expect(described_class.day_chart_from_horizon?(200.0, 10.0)).to be true  # offset 190
      expect(described_class.day_chart_from_horizon?(9.0, 10.0)).to be true    # offset 359
    end

    it "returns false when the Sun is in the below-horizon half (ASC forward to DSC)" do
      expect(described_class.day_chart_from_horizon?(10.0, 10.0)).to be false  # on the ASC
      expect(described_class.day_chart_from_horizon?(185.0, 10.0)).to be false # offset 175
    end

    it "returns nil when either input is missing" do
      expect(described_class.day_chart_from_horizon?(nil, 10.0)).to be_nil
      expect(described_class.day_chart_from_horizon?(100.0, nil)).to be_nil
    end

    it "agrees with the Placidus-cusps day_chart? test" do
      jd = AstroChart::Ephemeris.julday(2024, 6, 1, 4.0)
      [[25.03, 121.5], [52.6, -15.99], [-33.9, 151.2]].each do |lat, lon|
        cusps, asc = AstroChart::Houses.calculate(jd, lat, lon)
        sun = AstroChart::Ephemeris.calc_ut(jd, 0)
        expect(described_class.day_chart_from_horizon?(sun, asc))
          .to eq(described_class.day_chart?(sun, cusps))
      end
    end

    it "is independent of whole-sign cusps (sect stays horizon-based)" do
      # 1997-05-26 22:03 UT, lat 52.6, lng -15.99: the Sun sits below the
      # horizon (night) but inside whole-sign house 7 — the cusps-based test
      # with whole-sign cusps would misclassify this chart as a day birth.
      jd = AstroChart::Ephemeris.julday(1997, 5, 26, 22.05)
      whole_cusps, asc = AstroChart::Houses.calculate(jd, 52.6, -15.99, system: "W")
      sun = AstroChart::Ephemeris.calc_ut(jd, 0)

      expect(described_class.day_chart?(sun, whole_cusps)).to be true      # misleading
      expect(described_class.day_chart_from_horizon?(sun, asc)).to be false # horizon truth
    end
  end

  describe ".lilith" do
    it "returns the mean lunar apogee at J2000 (verified against Swiss Ephemeris)" do
      jd = AstroChart::Ephemeris.julday(2000, 1, 1, 12.0)
      # Swiss Ephemeris mean apogee (body 12) gives 263.4643; Meeus mean
      # elements agree to ~0.11 deg.
      expect(described_class.lilith(jd)).to be_within(0.2).of(263.46)
    end

    it "always returns a longitude in [0, 360)" do
      (1900..2050).step(10) do |year|
        jd = AstroChart::Ephemeris.julday(year, 6, 15, 0.0)
        lon = described_class.lilith(jd)
        expect(lon).to be >= 0.0
        expect(lon).to be < 360.0
      end
    end

    it "advances by the mean apogee daily motion (~0.111 deg/day)" do
      jd = AstroChart::Ephemeris.julday(2024, 1, 1, 0.0)
      motion = (described_class.lilith(jd + 1.0) - described_class.lilith(jd)) % 360.0
      expect(motion).to be_within(0.001).of(0.1114)
    end

    context "against the Swiss Ephemeris oracle", :swiss_oracle do
      swiss_available =
        begin
          AstroChart.load_swiss_extension!
          true
        rescue LoadError
          false
        end

      it "agrees with SE mean apogee (body 12) to <0.5 deg across 1900-2050" do
        skip "Swiss Ephemeris C extension not compiled" unless swiss_available

        begin
          AstroChart.backend = :swiss
          jd = AstroChart::Ephemeris.julday(1900, 1, 1, 0.0)
          jd_end = AstroChart::Ephemeris.julday(2050, 12, 31, 0.0)
          while jd <= jd_end
            swiss = AstroChart::Ephemeris.calc_ut(jd, 12)
            diff = (swiss - described_class.lilith(jd)).abs
            diff = 360.0 - diff if diff > 180.0
            expect(diff).to be < 0.5
            jd += 365.25
          end
        ensure
          AstroChart.backend = :pure
        end
      end
    end
  end
end
