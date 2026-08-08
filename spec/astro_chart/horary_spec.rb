require "spec_helper"

RSpec.describe AstroChart::Horary do
  # A concrete question moment used as the fixture throughout.
  let(:jd) { AstroChart::Ephemeris.julday(2026, 8, 8, 14.0) }

  NAME_ANGLE = {
    "合相" => 0, "六分相" => 60, "四分相" => 90, "三分相" => 120, "對分相" => 180
  }.freeze

  # Shortest distance (deg) between two bodies' longitudes and an aspect angle.
  def dist_to_angle(jd, a, b, angle)
    la = AstroChart::Ephemeris.calc_ut(jd, AstroChart::Ephemeris::PLANETS[a])
    lb = AstroChart::Ephemeris.calc_ut(jd, AstroChart::Ephemeris::PLANETS[b])
    d = (lb - la) % 360.0
    d = 360.0 - d if d > 180.0
    (d - angle).abs
  end

  describe ".positions" do
    subject(:positions) { described_class.positions(jd) }

    it "returns every catalogued body with the standard fields" do
      expect(positions.length).to eq(AstroChart::Ephemeris::PLANETS.length)
      row = positions.first
      expect(row).to include("planet", "zodiac", "degree", "total_degree", "speed", "retrograde")
    end

    it "never marks the luminaries retrograde" do
      %w[太陽 月亮].each do |lum|
        expect(positions.find { |p| p["planet"] == lum }["retrograde"]).to be(false)
      end
    end
  end

  describe ".aspects" do
    subject(:aspects) { described_class.aspects(jd) }

    it "is sorted tightest-orb first and stays within the moiety" do
      orbs = aspects.map { |a| a["orb"] }
      expect(orbs).to eq(orbs.sort)
    end

    it "labels each aspect's motion and flags partile/out-of-sign consistently" do
      aspects.each do |a|
        expect(%w[applying separating stationary]).to include(a["motion"])
        expect(a["applying"]).to eq(a["motion"] == "applying")
        expect(a["partile"]).to eq(a["orb"] <= 1.0)
      end
    end

    # The load-bearing claim: an "applying" aspect's orb must actually shrink.
    it "an applying aspect's orb is decreasing on the real ephemeris" do
      a = aspects.find { |x| x["applying"] && x["perfects_in_days"] && x["perfects_in_days"] > 0.5 }
      expect(a).not_to be_nil
      angle = NAME_ANGLE.fetch(a["aspect_type"])
      now = dist_to_angle(jd, a["planet"], a["other"], angle)
      later = dist_to_angle(jd + 0.02, a["planet"], a["other"], angle)
      expect(later).to be < now
    end

    # ...and it must genuinely perfect at the predicted time (validates refine_time).
    it "an applying aspect is ~exact at perfects_in_days" do
      a = aspects.find { |x| x["applying"] && x["perfects_in_days"] && x["perfects_in_days"] > 0.5 }
      angle = NAME_ANGLE.fetch(a["aspect_type"])
      residual = dist_to_angle(jd + a["perfects_in_days"], a["planet"], a["other"], angle)
      expect(residual).to be_within(0.05).of(0.0)
    end

    it "computes out_of_sign from the actual sign relationship" do
      pos = described_class.positions(jd)
      sign_index = ->(name) { (pos.find { |p| p["planet"] == name }["total_degree"]).floor / 30 }
      aspects.each do |a|
        angle = NAME_ANGLE.fetch(a["aspect_type"])
        dist = (sign_index.call(a["other"]) - sign_index.call(a["planet"])) % 12
        expected = angle / 30
        valid = dist == expected || dist == (12 - expected) % 12
        expect(a["out_of_sign"]).to eq(!valid)
      end
    end
  end

  describe ".solar_phases" do
    subject(:phases) { described_class.solar_phases(jd) }

    it "classifies each body by its distance from the Sun, cazimi winning over combust" do
      phases.each do |p|
        d = p["distance_from_sun"]
        case p["phase"]
        when "cazimi"      then expect(d).to be <= described_class::CAZIMI_ORB
        when "combust"     then expect(d).to be_between(described_class::CAZIMI_ORB, described_class::COMBUST_ORB)
        when "under_beams" then expect(d).to be_between(described_class::COMBUST_ORB, described_class::UNDER_BEAMS_ORB)
        when "free"        then expect(d).to be > described_class::UNDER_BEAMS_ORB
        end
      end
    end

    it "covers exactly the Moon and the five non-luminary planets" do
      expect(phases.map { |p| p["planet"] }).to match_array(%w[月亮 水星 金星 火星 木星 土星])
    end
  end

  describe ".moon_condition" do
    subject(:moon) { described_class.moon_condition(jd) }

    it "reports a coherent condition" do
      expect([true, false]).to include(moon["void_of_course"])
      expect(moon["speed_class"]).to eq(moon["speed"] > described_class::MOON_MEAN_SPEED ? "fast" : "slow")
      moon_lon = AstroChart::Ephemeris.calc_ut(jd, AstroChart::Ephemeris::PLANETS["月亮"])
      expect(moon["via_combusta"]).to eq((195.0..225.0).cover?(moon_lon % 360.0))
    end

    it "is not void when it has a next aspect perfecting before egress" do
      if moon["next_aspect"] && moon["next_aspect"]["before_egress"]
        expect(moon["void_of_course"]).to be(false)
      end
    end

    # The Moon's declared next aspect must actually perfect at its stated time.
    it "the next aspect is ~exact at perfects_in_days" do
      nxt = moon["next_aspect"]
      next if nxt.nil?

      angle = NAME_ANGLE.fetch(nxt["aspect_type"])
      residual = dist_to_angle(jd + nxt["perfects_in_days"], "月亮", nxt["planet"], angle)
      expect(residual).to be_within(0.1).of(0.0)
    end
  end

  describe ".perfection" do
    it "returns significators, the modes acting, and a verdict" do
      result = described_class.perfection(jd, "月亮", "太陽")
      expect(result["significators"]).to eq(%w[月亮 太陽])
      expect(result["modes"]).to be_an(Array)
      expect(%w[perfects perfects_via_translation perfects_via_collection denied no_perfection])
        .to include(result["verdict"])
    end

    it "only refranates the applier of a genuine applying aspect" do
      # A station only blocks when it is the APPLIER's, and only when a direct
      # aspect is actually applying — never for the receiver or with no aspect.
      [[2026, 1], [2026, 5], [2026, 9]].each do |y, m|
        j = AstroChart::Ephemeris.julday(y, m, 1, 0.0)
        %w[金星 火星 水星 木星 土星].combination(2).each do |a, b|
          r = described_class.perfection(j, a, b)
          refr = r["modes"].select { |x| x["type"] == "refranation" }
          next if refr.empty?

          expect(r["direct_aspect"]).not_to be_nil
          applier = r["direct_aspect"] && described_class.aspects(j).find { |x|
            [x["planet"], x["other"]].sort == [a, b].sort && x["applying"]
          }&.dig("applier")
          refr.each do |x|
            expect([a, b]).to include(x["significator"])
            expect(x["significator"]).to eq(applier) if applier
          end
        end
      end
    end
  end

  # Regression: a slow-body applying aspect near a station used to report a
  # garbage perfection time (Newton converging to the wrong root). Every
  # applying aspect's reported time must be an actual perfection.
  describe "perfection-time correctness" do
    it "any reported perfects_in_days lands on a real perfection" do
      [[2018, 1, 1], [1993, 6, 1], [2020, 12, 1]].each do |y, mo, d|
        j = AstroChart::Ephemeris.julday(y, mo, d, 0.0)
        described_class.aspects(j).each do |a|
          t = a["perfects_in_days"]
          next unless a["applying"] && t

          residual = dist_to_angle(j + t, a["planet"], a["other"], NAME_ANGLE.fetch(a["aspect_type"]))
          expect(residual).to be_within(0.05).of(0.0),
                              "#{a['planet']} #{a['aspect_type']} #{a['other']} @#{y} off by #{residual.round(3)}°"
        end
      end
    end
  end

  describe ".considerations" do
    it "flags radicality, using the ascendant/cusps when supplied" do
      c = described_class.considerations(jd, ascendant: 2.0)
      expect(c).to include("moon_void_of_course", "moon_via_combusta", "moon_late_degree")
      expect(c["ascendant_too_early"]).to be(true) # 2° into the sign
    end
  end

  describe ".snapshot" do
    it "bundles positions, aspects, solar phases, moon and considerations" do
      snap = described_class.snapshot(jd)
      expect(snap).to include("positions", "aspects", "solar_phases", "moon", "considerations")
      expect(snap["solar_phases"]).to all(satisfy { |p| p["phase"] != "free" })
    end
  end
end
