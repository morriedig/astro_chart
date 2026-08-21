require "spec_helper"

RSpec.describe AstroChart::PlanetaryHours do
  # Greenwich, where UT == local mean time, so almanac clock times compare directly.
  let(:lat) { 51.4779 }
  let(:lon) { 0.0 }

  # UT hour-of-day from a Julian Day.
  def ut_hours(jd)
    ((jd + 0.5) % 1.0) * 24.0
  end

  describe "sunrise / sunset" do
    it "places sunrise and sunset within 2 minutes of the published almanac" do
      jd = AstroChart::Ephemeris.julday(2024, 1, 1, 12.0)
      table = described_class.table(jd, latitude: lat, longitude: lon)
      # Greenwich 2024-01-01: sunrise 08:06, sunset 16:01 UT.
      expect(ut_hours(table[0]["hour_start"])).to be_within(2.0 / 60).of(8 + 6 / 60.0)
      expect(ut_hours(table[12]["hour_start"])).to be_within(2.0 / 60).of(16 + 1 / 60.0)
    end
  end

  describe ".day_ruler" do
    it "is the ruler of the local weekday" do
      # 2024-01-01 Mon→月亮, 02 Tue→火星, 03 Wed→水星, 04 Thu→木星,
      # 05 Fri→金星, 06 Sat→土星, 07 Sun→太陽.
      expected = { 1 => "月亮", 2 => "火星", 3 => "水星", 4 => "木星",
                   5 => "金星", 6 => "土星", 7 => "太陽" }
      expected.each do |day, ruler|
        jd = AstroChart::Ephemeris.julday(2024, 1, day, 12.0)
        expect(described_class.day_ruler(jd, latitude: lat, longitude: lon)).to eq(ruler)
      end
    end
  end

  describe ".at" do
    it "makes the first daytime hour the day ruler and reports daytime at noon" do
      jd = AstroChart::Ephemeris.julday(2024, 1, 1, 12.0)
      h = described_class.at(jd, latitude: lat, longitude: lon)
      expect(h["day_or_night"]).to eq("day")
      expect(h["hour_number"]).to be_between(1, 12)

      table = described_class.table(jd, latitude: lat, longitude: lon)
      expect(table.first["ruler"]).to eq(h["day_ruler"]) # hour 1 == day ruler
    end

    it "reports night around local midnight" do
      jd = AstroChart::Ephemeris.julday(2024, 1, 1, 0.0)
      h = described_class.at(jd, latitude: lat, longitude: lon)
      expect(h["day_or_night"]).to eq("night")
      expect(h["hour_number"]).to be_between(13, 24)
    end

    it "agrees with the 24-hour table for the hour containing the instant" do
      jd = AstroChart::Ephemeris.julday(2024, 3, 15, 9.0)
      h = described_class.at(jd, latitude: lat, longitude: lon)
      row = described_class.table(jd, latitude: lat, longitude: lon)
                           .find { |r| jd >= r["hour_start"] && jd < r["hour_end"] }
      expect(row["hour_number"]).to eq(h["hour_number"])
      expect(row["ruler"]).to eq(h["hour_ruler"])
    end
  end

  describe ".table" do
    subject(:table) { described_class.table(AstroChart::Ephemeris.julday(2024, 1, 1, 12.0), latitude: lat, longitude: lon) }

    it "is 24 contiguous hours spanning sunrise to the next sunrise" do
      expect(table.length).to eq(24)
      table.each_cons(2) { |a, b| expect(b["hour_start"]).to be_within(1e-9).of(a["hour_end"]) }
    end

    it "steps the rulers through the Chaldean order from the day ruler" do
      chaldean = AstroChart::PlanetaryHours::CHALDEAN
      start = chaldean.index(table.first["ruler"])
      table.each_with_index do |row, i|
        expect(row["ruler"]).to eq(chaldean[(start + i) % 7])
      end
    end

    it "splits day and night into twelve each, with unequal winter lengths" do
      day = table.first(12)
      night = table.last(12)
      expect(day.map { |h| h["day_or_night"] }).to all(eq("day"))
      expect(night.map { |h| h["day_or_night"] }).to all(eq("night"))
      day_len = day.first["hour_end"] - day.first["hour_start"]
      night_len = night.first["hour_end"] - night.first["hour_start"]
      # London in January: short days, so a night hour is longer than a day hour.
      expect(night_len).to be > day_len
    end
  end

  describe "circumpolar latitudes" do
    it "raises when the Sun does not set (polar midsummer)" do
      jd = AstroChart::Ephemeris.julday(2024, 6, 21, 0.0)
      expect { described_class.at(jd, latitude: 78.2, longitude: 15.6) }
        .to raise_error(AstroChart::Pure::Core::DomainError)
    end
  end
end
