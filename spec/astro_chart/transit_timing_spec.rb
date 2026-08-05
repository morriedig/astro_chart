require "spec_helper"

RSpec.describe AstroChart::TransitTiming do
  let(:natal) do
    AstroChart::Chart.new(
      birth_date: "1990-01-01", birth_time: "12:00",
      latitude: 25.033, longitude: 121.5654, timezone: "Asia/Taipei"
    ).generate
  end

  ANGLE = { "合相" => 0, "六分相" => 60, "四分相" => 90, "三分相" => 120, "對分相" => 180,
            "十二分相" => 30, "半四分相" => 45, "補八分相" => 135, "補十二分相" => 150 }.freeze

  def natal_deg(name)
    natal["chart"]["planets"].find { |p| p["planet"] == name }["total_degree"]
  end

  def signed_sep(lon, natal_lon)
    d = (lon - natal_lon) % 360.0
    d > 180.0 ? d - 360.0 : d
  end

  describe ".events" do
    subject(:events) { described_class.events(natal, "2026-01-01", "2026-03-31", bodies: ["太陽"]) }

    it "returns events sorted by time" do
      jds = events.map { |e| e["jd"] }
      expect(jds).to eq(jds.sort)
      expect(events).not_to be_empty
    end

    it "places every event at the exact aspect separation" do
      sun_id = AstroChart::Ephemeris::PLANETS["太陽"]
      events.each do |e|
        lon = AstroChart::Ephemeris.calc_ut(e["jd"], sun_id)
        sep = signed_sep(lon, natal_deg(e["natal_planet"]))
        target = ANGLE.fetch(e["aspect_type"])
        # exact within ~1 arcminute; compare |sep| to the aspect angle
        expect(sep.abs).to be_within(0.02).of(target)
      end
    end

    it "keeps every event inside the requested range" do
      jd_start = AstroChart::Ephemeris.julday(2026, 1, 1, 0.0)
      jd_end   = AstroChart::Ephemeris.julday(2026, 3, 31, 0.0)
      events.each do |e|
        expect(e["jd"]).to be_between(jd_start, jd_end)
      end
    end

    it "reports the Sun as never retrograde and carries an ISO time" do
      events.each do |e|
        expect(e["retrograde"]).to eq(false)
        expect(e["time_utc"]).to match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/)
      end
    end

    it "excludes minor aspects unless minor: true" do
      major = described_class.events(natal, "2026-01-01", "2026-06-30", bodies: ["太陽"])
      withm = described_class.events(natal, "2026-01-01", "2026-06-30", bodies: ["太陽"], minor: true)
      expect(major.map { |e| e["aspect_type"] }.uniq).to all(satisfy { |t| ANGLE[t] && [0, 60, 90, 120, 180].include?(ANGLE[t]) })
      expect(withm.length).to be > major.length
      expect(withm.map { |e| e["aspect_type"] }).to include("補十二分相").or include("十二分相")
    end

    it "does not report duplicate contacts at bracket boundaries" do
      keys = events.map { |e| [e["transit_planet"], e["natal_planet"], e["aspect_type"], e["jd"].round(2)] }
      expect(keys.uniq.length).to eq(keys.length)
    end

    it "catches all three passes of a retrograde outer-planet contact" do
      # 土星 retrograde loops can perfect the same natal aspect up to 3 times.
      sat = described_class.events(natal, "2024-01-01", "2027-12-31", bodies: ["土星"])
      grouped = sat.group_by { |e| [e["natal_planet"], e["aspect_type"]] }
      expect(grouped.values.map(&:length).max).to be >= 3
    end
  end
end
