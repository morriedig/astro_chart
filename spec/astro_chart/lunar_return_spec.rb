require "spec_helper"

RSpec.describe AstroChart::LunarReturn do
  let(:natal) do
    AstroChart::Chart.new(
      birth_date: "1990-01-01", birth_time: "12:00",
      latitude: 25.033, longitude: 121.5654, timezone: "Asia/Taipei"
    ).generate
  end

  def natal_moon
    natal["chart"]["planets"].find { |p| p["planet"] == "月亮" }["total_degree"]
  end

  describe ".for_date" do
    subject(:result) { described_class.for_date(natal, "2026-07-24") }

    it "puts the Moon back on its natal longitude" do
      moon = result["chart"]["planets"].find { |p| p["planet"] == "月亮" }["total_degree"]
      diff = (moon - natal_moon) % 360.0
      diff -= 360.0 if diff > 180.0
      expect(diff.abs).to be < 0.001
    end

    it "returns an instant within half a lunar cycle of the target date" do
      target_jd = AstroChart::Ephemeris.julday(2026, 7, 24, 0.0)
      expect((result["return_jd"] - target_jd).abs).to be <= 14.0
    end

    it "carries an ISO UTC time and the natal location by default" do
      expect(result["return_time_utc"]).to match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/)
      expect(result["location"]["latitude"]).to be_within(1e-6).of(25.033)
    end

    it "relocates when given coordinates" do
      relocated = described_class.for_date(natal, "2026-07-24", latitude: 51.5, longitude: -0.13)
      expect(relocated["location"]["latitude"]).to eq(51.5)
      # same return instant, different ascendant
      expect(relocated["return_jd"]).to be_within(1e-9).of(result["return_jd"])
      expect(relocated["chart"]["ascendant"]["total_degree"])
        .not_to be_within(0.1).of(result["chart"]["ascendant"]["total_degree"])
    end

    it "raises when no coordinates are available" do
      no_coords = { "input" => { "birth_date" => "1990-01-01" },
                    "chart" => { "planets" => [{ "planet" => "月亮", "total_degree" => 100.0 }] } }
      expect { described_class.for_date(no_coords, "2026-07-24") }
        .to raise_error(ArgumentError, /no coordinates/)
    end
  end
end
