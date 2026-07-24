require "spec_helper"

RSpec.describe "AstroChart::Ephemeris.speed" do
  # Swiss oracle is only available locally (compiled C ext); skip cleanly elsewhere.
  swiss_available =
    begin
      AstroChart.load_swiss_extension!
      true
    rescue LoadError
      false
    end

  after { AstroChart.backend = :pure }

  SUN     = AstroChart::Ephemeris::PLANETS["太陽"]
  MOON    = AstroChart::Ephemeris::PLANETS["月亮"]
  MERCURY = AstroChart::Ephemeris::PLANETS["水星"]

  describe ".speed" do
    it "returns the Sun's daily motion (~0.95..1.02 deg/day)" do
      jd = AstroChart::Ephemeris.julday(2021, 10, 10, 0.0)
      expect(AstroChart::Ephemeris.speed(jd, SUN)).to be_between(0.95, 1.02)
    end

    it "returns the Moon's daily motion (~11.7..15.4 deg/day)" do
      jd = AstroChart::Ephemeris.julday(2021, 10, 10, 0.0)
      expect(AstroChart::Ephemeris.speed(jd, MOON)).to be_between(11.7, 15.4)
    end

    it "handles the 0/360 wraparound (Sun crossing 0 Aries)" do
      # 2023 March equinox: Sun longitude crosses 0 within jd +/- 0.5,
      # so the raw difference is ~ -359 before folding.
      jd = AstroChart::Ephemeris.julday(2023, 3, 20, 21.5)
      expect(AstroChart::Ephemeris.calc_ut(jd - 0.5, SUN)).to be > 350.0
      expect(AstroChart::Ephemeris.calc_ut(jd + 0.5, SUN)).to be < 10.0
      expect(AstroChart::Ephemeris.speed(jd, SUN)).to be_between(0.9, 1.1)
    end

    it "is negative for Mercury mid-retrograde" do
      # Mercury was retrograde 2022-01-14 .. 2022-02-03
      jd = AstroChart::Ephemeris.julday(2022, 1, 25, 0.0)
      expect(AstroChart::Ephemeris.speed(jd, MERCURY)).to be < 0
    end
  end

  describe ".speed near ephemeris range edges" do
    PLUTO = AstroChart::Ephemeris::PLANETS["冥王星"]

    it "falls back to a forward difference at the Pluto series' lower bound" do
      # jd - 0.5 is out of the pure Pluto range (1885-2099), jd itself is in.
      jd = AstroChart::Ephemeris.julday(1885, 1, 1, 6.0)
      expect { AstroChart::Ephemeris.calc_ut(jd - 0.5, PLUTO) }
        .to raise_error(AstroChart::Pure::Core::DomainError)

      speed = AstroChart::Ephemeris.speed(jd, PLUTO)
      expect(speed.abs).to be < 0.1 # Pluto moves well under 0.1 deg/day
    end

    it "falls back to a backward difference at the Pluto series' upper bound" do
      jd = AstroChart::Ephemeris.julday(2099, 12, 31, 20.0)
      expect { AstroChart::Ephemeris.calc_ut(jd + 0.5, PLUTO) }
        .to raise_error(AstroChart::Pure::Core::DomainError)

      speed = AstroChart::Ephemeris.speed(jd, PLUTO)
      expect(speed.abs).to be < 0.1
    end

    it "agrees with the interior central difference nearby" do
      edge_jd = AstroChart::Ephemeris.julday(1885, 1, 1, 6.0)
      interior_jd = AstroChart::Ephemeris.julday(1885, 1, 3, 6.0)
      expect(AstroChart::Ephemeris.speed(edge_jd, PLUTO))
        .to be_within(0.001).of(AstroChart::Ephemeris.speed(interior_jd, PLUTO))
    end

    it "still raises DomainError when jd itself is out of range" do
      jd = AstroChart::Ephemeris.julday(1884, 12, 1, 0.0)
      expect { AstroChart::Ephemeris.speed(jd, PLUTO) }
        .to raise_error(AstroChart::Pure::Core::DomainError)
    end
  end

  describe ".retrograde?" do
    it "is true for Mercury mid-retrograde" do
      jd = AstroChart::Ephemeris.julday(2022, 1, 25, 0.0)
      expect(AstroChart::Ephemeris.retrograde?(jd, MERCURY)).to be(true)
    end

    it "is false for Mercury in direct motion" do
      jd = AstroChart::Ephemeris.julday(2022, 4, 15, 0.0)
      expect(AstroChart::Ephemeris.retrograde?(jd, MERCURY)).to be(false)
    end

    it "is always false for the Sun" do
      (2020..2024).each do |year|
        jd = AstroChart::Ephemeris.julday(year, 6, 1, 0.0)
        expect(AstroChart::Ephemeris.retrograde?(jd, SUN)).to be(false)
      end
    end
  end

  describe "against the Swiss Ephemeris oracle", if: swiss_available do
    it "matches Swiss-derived speed sign and magnitude for Mercury through 2022" do
      jd0 = AstroChart::Ephemeris.julday(2022, 1, 1, 0.0)
      (0...73).each do |k|
        jd = jd0 + k * 5.0

        AstroChart.backend = :pure
        pure_speed = AstroChart::Ephemeris.speed(jd, MERCURY)

        AstroChart.backend = :swiss
        swiss_speed = AstroChart::Ephemeris.speed(jd, MERCURY)

        expect(pure_speed.negative?).to eq(swiss_speed.negative?),
          "jd=#{jd}: pure=#{pure_speed} swiss=#{swiss_speed}"
        expect(pure_speed).to be_within(0.05).of(swiss_speed)
      end
    end
  end
end
