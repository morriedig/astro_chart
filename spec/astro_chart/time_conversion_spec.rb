require "spec_helper"

RSpec.describe AstroChart::TimeConversion do
  describe ".to_julian_day" do
    it "converts a known date to Julian Day" do
      # J2000.0 epoch: 2000-01-01 12:00 UTC = JD 2451545.0
      jd = described_class.to_julian_day("2000-01-01", "12:00", "Etc/UTC")
      expect(jd).to be_within(0.001).of(2451545.0)
    end

    it "handles timezone offset correctly" do
      # Asia/Taipei is UTC+8, so 2000-01-01 20:00 Taipei = 2000-01-01 12:00 UTC
      jd = described_class.to_julian_day("2000-01-01", "20:00", "Asia/Taipei")
      expect(jd).to be_within(0.001).of(2451545.0)
    end

    it "returns a reasonable Julian Day for a modern date" do
      jd = described_class.to_julian_day("1990-01-01", "12:00", "Asia/Taipei")
      # 1990-01-01 12:00 Taipei = 1990-01-01 04:00 UTC -> JD ~2447892.667
      expect(jd).to be_within(0.01).of(2447892.667)
    end
  end
end
