require "spec_helper"
require "date"
require "astro_chart/solar_return"

RSpec.describe AstroChart::SolarReturn do
  SWISS_EXT_AVAILABLE =
    begin
      AstroChart.load_swiss_extension!
      true
    rescue LoadError
      false
    end

  let(:natal) do
    AstroChart::Chart.new(
      birth_date: "1988-07-03", birth_time: "09:20",
      latitude: 22.6273, longitude: 120.3014, timezone: "Asia/Taipei"
    ).generate
  end

  let(:natal_sun) do
    natal["chart"]["planets"].find { |p| p["planet"] == "太陽" }["total_degree"]
  end

  def shortest_arc(deg)
    (deg + 540.0) % 360.0 - 180.0
  end

  describe ".jd_to_utc / .jd_to_utc_iso8601" do
    it "round-trips Ephemeris.julday for plain dates" do
      [
        [2000, 1, 1, 12.0],
        [1988, 7, 3, 0.0],
        [2026, 12, 31, 6.0],
        [1600, 3, 1, 0.0],
      ].each do |y, m, d, h|
        jd = AstroChart::Ephemeris.julday(y, m, d, h)
        expect(described_class.jd_to_utc(jd)).to eq([y, m, d, h.to_i, 0, 0])
      end
    end

    it "round-trips fractional hours to minutes and seconds" do
      jd = AstroChart::Ephemeris.julday(1988, 7, 3, 1 + 20 / 60.0)
      expect(described_class.jd_to_utc_iso8601(jd)).to eq("1988-07-03T01:20:00Z")

      jd = AstroChart::Ephemeris.julday(2024, 6, 5, 18.5)
      expect(described_class.jd_to_utc_iso8601(jd)).to eq("2024-06-05T18:30:00Z")

      jd = AstroChart::Ephemeris.julday(2024, 6, 5, 23 + 59 / 60.0 + 59 / 3600.0)
      expect(described_class.jd_to_utc_iso8601(jd)).to eq("2024-06-05T23:59:59Z")
    end

    it "handles the leap day" do
      jd = AstroChart::Ephemeris.julday(2024, 2, 29, 23.0)
      expect(described_class.jd_to_utc_iso8601(jd)).to eq("2024-02-29T23:00:00Z")
    end

    it "rolls a sub-second remainder over to the next day instead of emitting 24:00" do
      jd = AstroChart::Ephemeris.julday(1999, 12, 31, 23.9999999)
      expect(described_class.jd_to_utc_iso8601(jd)).to eq("2000-01-01T00:00:00Z")
    end

    it "round-trips the known epoch J2000.0" do
      expect(described_class.jd_to_utc(2_451_545.0)).to eq([2000, 1, 1, 12, 0, 0])
    end

    it "survives many random round-trips within a second" do
      srand(42)
      50.times do
        y = 1900 + rand(200)
        m = 1 + rand(12)
        d = 1 + rand(28)
        h = rand * 24.0
        jd = AstroChart::Ephemeris.julday(y, m, d, h)
        ry, rm, rd, rh, rmin, rs = described_class.jd_to_utc(jd)
        back = AstroChart::Ephemeris.julday(ry, rm, rd, rh + rmin / 60.0 + rs / 3600.0)
        expect((back - jd).abs * 86_400.0).to be < 0.51 # rounded to nearest second
      end
    end
  end

  describe ".find_return_jd" do
    it "converges to the natal Sun longitude within 1e-4°" do
      jd = described_class.find_return_jd(natal_sun, 2024, 7, 3)
      sun = AstroChart::Ephemeris.calc_ut(jd, described_class::SUN_ID)

      expect(shortest_arc(natal_sun - sun).abs).to be < 1e-4
    end

    it "raises ConvergenceError when it cannot converge" do
      allow(described_class).to receive(:sun_speed).and_return(1e9) # steps never move
      expect { described_class.find_return_jd(200.0, 2024, 7, 3) }
        .to raise_error(AstroChart::SolarReturn::ConvergenceError)
    end
  end

  describe ".sun_speed" do
    it "is close to the mean solar motion of ~0.9856°/day" do
      jd = AstroChart::Ephemeris.julday(2024, 7, 3, 0.0)
      expect(described_class.sun_speed(jd)).to be_within(0.05).of(0.9856)
    end
  end

  describe ".for_year" do
    let(:result) { described_class.for_year(natal, 2024) }

    it "returns a Sun longitude equal to the natal Sun within 1e-3°" do
      sun = result["chart"]["planets"].find { |p| p["planet"] == "太陽" }
      expect(shortest_arc(natal_sun - sun["total_degree"]).abs).to be < 1e-3
    end

    it "returns a date within ±2 days of the birthday" do
      y, m, d, = described_class.jd_to_utc(result["return_jd"])
      returned = Date.new(y, m, d)
      birthday = Date.new(2024, 7, 3)

      expect((returned - birthday).to_i.abs).to be <= 2
    end

    it "reports return_time_utc consistent with return_jd" do
      expect(result["return_time_utc"])
        .to eq(described_class.jd_to_utc_iso8601(result["return_jd"]))
      expect(result["return_time_utc"]).to match(/\A2024-0[67]-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
    end

    it "defaults location to the natal chart's coordinates and timezone" do
      expect(result["location"]).to eq(
        "latitude"  => 22.6273,
        "longitude" => 120.3014,
        "timezone"  => "Asia/Taipei"
      )
    end

    it "builds a full chart structure (ascendant, 15 planet entries, 12 houses)" do
      chart = result["chart"]

      expect(chart["ascendant"]).to include("zodiac", "degree", "total_degree")
      expect(AstroChart::Zodiac::SIGNS).to include(chart["ascendant"]["zodiac"])

      names = chart["planets"].map { |p| p["planet"] }
      expect(names).to include(*AstroChart::Ephemeris::PLANETS.keys, "南交點")
      expect(names).to include("北交點定位星", "南交點定位星", "上升星座定位星")
      expect(chart["planets"].length).to eq(15)

      expect(chart["houses"].length).to eq(12)
      chart["houses"].each do |h|
        expect(h["house_number"]).to be_between(1, 12)
        expect(AstroChart::Zodiac::SIGNS).to include(h["zodiac"])
      end
    end

    it "merges aspects into the key planets like Chart#generate" do
      sun = result["chart"]["planets"].find { |p| p["planet"] == "太陽" }
      expect(sun).to have_key("aspects")
    end

    it "relocates houses when latitude/longitude are overridden" do
      relocated = described_class.for_year(natal, 2024, latitude: 51.5074, longitude: -0.1278)

      expect(relocated["return_jd"]).to eq(result["return_jd"]) # same instant
      expect(relocated["location"]["latitude"]).to eq(51.5074)
      expect(relocated["chart"]["ascendant"]["total_degree"])
        .not_to eq(result["chart"]["ascendant"]["total_degree"])
    end

    it "keeps consecutive returns roughly a year apart" do
      jd_2024 = described_class.for_year(natal, 2024)["return_jd"]
      jd_2025 = described_class.for_year(natal, 2025)["return_jd"]

      expect(jd_2025 - jd_2024).to be_within(0.1).of(365.25)
    end

    it "raises on a chart hash without planets" do
      expect { described_class.for_year({}, 2024) }
        .to raise_error(ArgumentError, /planets/)
    end

    it "raises when the chart lacks a birth_date" do
      broken = { "chart" => natal["chart"] } # no input block
      expect { described_class.for_year(broken, 2024) }
        .to raise_error(ArgumentError, /birth_date/)
    end

    it "raises when no coordinates are available anywhere" do
      no_coords = {
        "input" => { "birth_date" => "1988-07-03" },
        "chart" => natal["chart"],
      }
      expect { described_class.for_year(no_coords, 2024) }
        .to raise_error(ArgumentError, /coordinates/)
    end
  end

  describe "Swiss ephemeris oracle cross-check", if: SWISS_EXT_AVAILABLE do
    after { AstroChart.backend = :pure }

    it "matches Swiss planet longitudes at the return instant within 0.01°" do
      [2024, 2026].each do |year|
        jd = described_class.for_year(natal, year)["return_jd"]

        AstroChart::Ephemeris::PLANETS.each do |name, pid|
          AstroChart.backend = :pure
          pure = AstroChart::Ephemeris.calc_ut(jd, pid)
          AstroChart.backend = :swiss
          swiss = AstroChart::Ephemeris.calc_ut(jd, pid)

          diff = shortest_arc(pure - swiss).abs
          expect(diff).to be < 0.01, "#{year} #{name}: pure #{pure} vs swiss #{swiss} (diff #{diff})"
        end
      end
    end

    it "hits the natal Sun longitude per the Swiss ephemeris within 1e-3°" do
      jd = described_class.for_year(natal, 2024)["return_jd"]

      AstroChart.backend = :swiss
      swiss_sun = AstroChart::Ephemeris.calc_ut(jd, described_class::SUN_ID)

      expect(shortest_arc(natal_sun - swiss_sun).abs).to be < 1e-3
    end
  end
end
