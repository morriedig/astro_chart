require "spec_helper"
require "astro_chart/transits"

RSpec.describe AstroChart::Transits do
  # 2001-06-21 00:00 UT — June solstice, Sun ~89.7°
  let(:jd) { AstroChart::Ephemeris.julday(2001, 6, 21, 0.0) }

  describe ".at" do
    let(:sky) { described_class.at(jd) }

    it "returns the 12 bodies (Ephemeris::PLANETS + 南交點)" do
      expect(sky.keys).to match_array(AstroChart::Ephemeris::PLANETS.keys + ["南交點"])
      expect(sky.length).to eq(12)
    end

    it "returns ecliptic longitudes in [0, 360)" do
      sky.each_value do |lon|
        expect(lon).to be_a(Float)
        expect(lon).to be >= 0
        expect(lon).to be < 360
      end
    end

    it "puts 南交點 exactly opposite 北交點" do
      expect(sky["南交點"]).to be_within(1e-9).of((sky["北交點"] + 180.0) % 360.0)
    end

    it "matches known sky: solstice Sun at ~90°" do
      expect(sky["太陽"]).to be_within(0.1).of(89.7)
    end
  end

  describe ".planet_details" do
    let(:equal_cusps) { (0...12).map { |i| i * 30.0 } }

    it "builds zodiac / degree / total_degree / natal_house per body" do
      details = described_class.planet_details({ "太陽" => 95.1234567 }, equal_cusps)

      expect(details).to eq([{
        "planet"       => "太陽",
        "zodiac"       => "巨蟹座",
        "degree"       => 5.1235,
        "total_degree" => 95.1235,
        "natal_house"  => 4,
      }])
    end
  end

  describe ".aspects_to_natal" do
    it "finds aspects and filters by orb_limit" do
      moving = { "土星" => 100.0 }
      natal  = { "太陽" => 12.0 } # 88° => square, orb 2

      hits = described_class.aspects_to_natal(moving, natal, orb_limit: 3.0)
      expect(hits).to eq([{
        "transit_planet" => "土星",
        "natal_planet"   => "太陽",
        "aspect_type"    => "四分相",
        "orb"            => 2.0,
      }])

      expect(described_class.aspects_to_natal(moving, natal, orb_limit: 1.0)).to be_empty
    end

    it "sorts by orb, tightest first" do
      moving = { "木星" => 0.0, "土星" => 91.0 }
      natal  = { "太陽" => 90.0 } # 木星: 90° square, orb 0; 土星: conjunction, orb 1

      hits = described_class.aspects_to_natal(moving, natal, orb_limit: 3.0)
      expect(hits.map { |h| h["orb"] }).to eq(hits.map { |h| h["orb"] }.sort)
      expect(hits.first["transit_planet"]).to eq("木星")
    end

    it "excludes 南交點 as a moving body (mirror of 北交點)" do
      moving = { "南交點" => 90.0 }
      natal  = { "太陽" => 90.0 }

      expect(described_class.aspects_to_natal(moving, natal, orb_limit: 3.0)).to be_empty
    end

    it "supports custom key names" do
      hits = described_class.aspects_to_natal(
        { "月亮" => 10.0 }, { "太陽" => 10.0 },
        orb_limit: 1.0, keys: %w[progressed_planet natal_planet]
      )

      expect(hits.first.keys).to include("progressed_planet", "natal_planet")
    end
  end

  describe ".against (integration with Chart)" do
    let(:natal_chart) do
      AstroChart::Chart.new(
        birth_date: "1988-07-03", birth_time: "09:20",
        latitude: 22.6273, longitude: 120.3014, timezone: "Asia/Taipei"
      ).generate
    end

    let(:result) { described_class.against(natal_chart, jd) }

    it "lists all 12 transiting bodies with natal house placement" do
      expect(result["planets"].length).to eq(12)
      result["planets"].each do |p|
        expect(p.keys).to match_array(%w[planet zodiac degree total_degree natal_house])
        expect(AstroChart::Zodiac::SIGNS).to include(p["zodiac"])
        expect(p["natal_house"]).to be_between(1, 12)
        expect(p["degree"]).to be < 30
        expect(p["total_degree"]).to be_within(1e-6).of(
          AstroChart::Zodiac::SIGNS.index(p["zodiac"]) * 30 + p["degree"]
        )
      end
    end

    it "places transiting planets using the natal cusps" do
      cusps = AstroChart::Synastry.cusps_from_chart(natal_chart)
      result["planets"].each do |p|
        expect(p["natal_house"]).to eq(AstroChart::Houses.find_house(p["total_degree"], cusps))
      end
    end

    it "returns transit-to-natal aspects within the default 3° orb, sorted" do
      orbs = result["aspects"].map { |a| a["orb"] }
      expect(orbs).to eq(orbs.sort)
      result["aspects"].each do |a|
        expect(a["orb"]).to be <= 3.0
        expect(AstroChart::Synastry::BODIES).to include(a["transit_planet"])
        expect(AstroChart::Synastry::BODIES).to include(a["natal_planet"])
        expect(%w[合相 六分相 四分相 三分相 對分相]).to include(a["aspect_type"])
      end
    end

    it "tightening orb_limit only removes aspects" do
      tight = described_class.against(natal_chart, jd, orb_limit: 1.0)
      expect(tight["aspects"].length).to be <= result["aspects"].length
      tight["aspects"].each { |a| expect(a["orb"]).to be <= 1.0 }
    end

    it "raises on a chart hash without planets" do
      expect { described_class.against({}, jd) }.to raise_error(ArgumentError, /planets/)
    end
  end

  # Cross-check against the locally compiled Swiss Ephemeris C extension.
  # Skipped cleanly wherever the extension is absent (CI/prod).
  swiss_bundle = File.expand_path("../../lib/astro_chart/astro_chart_ext.bundle", __dir__)
  describe "Swiss Ephemeris oracle", if: File.exist?(swiss_bundle) do
    after { AstroChart.backend = :pure }

    datetimes = [
      [1962, 3, 14, 4.50],
      [1987, 11, 2, 18.25],
      [2001, 6, 21, 0.00],
      [2019, 12, 31, 23.75],
      [2033, 8, 7, 9.10],
    ]

    datetimes.each do |y, m, d, h|
      it "matches :swiss within 0.02° at #{y}-#{m}-#{d} #{h}h UT" do
        jd = AstroChart::Ephemeris.julday(y, m, d, h)

        AstroChart.backend = :pure
        pure = described_class.at(jd)

        AstroChart.backend = :swiss
        swiss = described_class.at(jd)

        pure.each do |name, lon|
          delta = (lon - swiss[name]).abs
          delta = 360.0 - delta if delta > 180.0
          expect(delta).to be < 0.02, "#{name}: pure #{lon} vs swiss #{swiss[name]} (delta #{delta})"
        end
      end
    end
  end
end
