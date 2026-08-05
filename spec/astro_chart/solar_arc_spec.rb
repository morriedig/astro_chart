require "spec_helper"

RSpec.describe AstroChart::SolarArc do
  let(:natal) do
    AstroChart::Chart.new(
      birth_date: "1990-01-01", birth_time: "12:00",
      latitude: 25.033, longitude: 121.5654, timezone: "Asia/Taipei"
    ).generate
  end

  describe ".directions" do
    subject(:result) { described_class.directions(natal, "2026-07-24") }

    it "directs the chart by roughly one degree per year of life" do
      # ~36.5 years old; winter Sun moves slightly faster than 1°/day
      expect(result["arc"]).to be_within(2.0).of(37.0)
    end

    it "advances every natal point rigidly by the arc" do
      arc = result["arc"]
      natal_positions = AstroChart::Synastry.positions_from_chart(natal)
      result["planets"].each do |directed|
        expected = (natal_positions[directed["planet"]] + arc) % 360.0
        expect(directed["total_degree"]).to be_within(1e-3).of(expected.round(4))
      end
    end

    it "reports directed-to-natal aspects sorted by orb" do
      orbs = result["aspects_to_natal"].map { |a| a["orb"] }
      expect(orbs).to eq(orbs.sort)
      result["aspects_to_natal"].each do |a|
        expect(a).to have_key("directed_planet")
        expect(a).to have_key("natal_planet")
      end
    end

    it "raises without natal input data" do
      expect { described_class.directions({ "chart" => {} }, "2026-07-24") }
        .to raise_error(ArgumentError)
    end
  end
end
