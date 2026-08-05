require "spec_helper"
require "astro_chart/patterns"

RSpec.describe AstroChart::Patterns do
  def of_type(results, type)
    results.select { |r| r["pattern_type"] == type }
  end

  describe ".detect" do
    context "大三角 (Grand Trine)" do
      it "detects an exact grand trine with a shared element" do
        positions = { "太陽" => 10, "木星" => 130, "火星" => 250 }
        results = described_class.detect(positions)

        expect(results.length).to eq(1)
        trine = results.first
        expect(trine["pattern_type"]).to eq("大三角")
        expect(trine["planets"]).to contain_exactly("太陽", "木星", "火星")
        expect(trine["element"]).to eq("火")
      end

      it "reports element nil when signs span different elements" do
        # 28 牡羊(火), 152 處女(土), 270 摩羯(土) — pairwise trine within orb
        positions = { "太陽" => 28, "月亮" => 152, "木星" => 270 }
        results = described_class.detect(positions)

        trines = of_type(results, "大三角")
        expect(trines.length).to eq(1)
        expect(trines.first["element"]).to be_nil
      end

      it "detects a grand trine across the 0° wraparound" do
        positions = { "月亮" => 350, "金星" => 110, "土星" => 230 }
        results = described_class.detect(positions)

        trines = of_type(results, "大三角")
        expect(trines.length).to eq(1)
        expect(trines.first["planets"]).to contain_exactly("月亮", "金星", "土星")
        expect(trines.first["element"]).to eq("水")
      end

      it "accepts trine legs at exactly the 8° orb limit" do
        # 0-128 orb 8, 128-240 orb 8, 0-240 exact
        positions = { "太陽" => 0, "木星" => 128, "火星" => 240 }
        results = described_class.detect(positions)

        trines = of_type(results, "大三角")
        expect(trines.length).to eq(1)
        expect(trines.first["element"]).to eq("火")
      end

      it "rejects a leg just outside the 8° orb limit" do
        positions = { "太陽" => 0, "木星" => 128.5, "火星" => 240 }
        results = described_class.detect(positions)

        expect(of_type(results, "大三角")).to be_empty
      end

      it "reports each grand trine once and finds overlapping trios" do
        # {太陽,木星,土星} and {水星,木星,土星} both pairwise trine;
        # 太陽-水星 is a conjunction so the trio {太陽,水星,X} never qualifies.
        positions = { "太陽" => 0, "水星" => 5, "木星" => 120, "土星" => 240 }
        results = described_class.detect(positions)

        trines = of_type(results, "大三角")
        expect(trines.length).to eq(2)
        planet_sets = trines.map { |t| t["planets"].sort }
        expect(planet_sets).to contain_exactly(
          ["太陽", "木星", "土星"].sort,
          ["水星", "木星", "土星"].sort
        )
      end

      it "ignores bodies unrelated to the pattern" do
        positions = { "太陽" => 10, "木星" => 130, "火星" => 250, "水星" => 52 }
        results = described_class.detect(positions)

        trines = of_type(results, "大三角")
        expect(trines.length).to eq(1)
        expect(trines.first["planets"]).to contain_exactly("太陽", "木星", "火星")
      end
    end

    context "T三角 (T-Square)" do
      it "detects an exact T-square and reports the apex" do
        positions = { "太陽" => 0, "月亮" => 180, "火星" => 90 }
        results = described_class.detect(positions)

        expect(results.length).to eq(1)
        t = results.first
        expect(t["pattern_type"]).to eq("T三角")
        expect(t["planets"]).to contain_exactly("太陽", "月亮", "火星")
        expect(t["apex"]).to eq("火星")
      end

      it "accepts an opposition at exactly the 10° orb limit" do
        positions = { "太陽" => 0, "月亮" => 190, "火星" => 95 }
        results = described_class.detect(positions)

        ts = of_type(results, "T三角")
        expect(ts.length).to eq(1)
        expect(ts.first["apex"]).to eq("火星")
      end

      it "rejects an opposition just outside the 10° orb limit" do
        positions = { "太陽" => 0, "月亮" => 190.5, "火星" => 95 }
        results = described_class.detect(positions)

        expect(of_type(results, "T三角")).to be_empty
      end

      it "does not build a T-square on the 北交點-南交點 axis alone" do
        positions = { "北交點" => 0, "南交點" => 180, "火星" => 90 }
        results = described_class.detect(positions)

        expect(results).to be_empty
      end

      it "allows a node to participate when the opposition is not the node axis" do
        positions = { "北交點" => 0, "太陽" => 180, "火星" => 90 }
        results = described_class.detect(positions)

        ts = of_type(results, "T三角")
        expect(ts.length).to eq(1)
        expect(ts.first["planets"]).to contain_exactly("北交點", "太陽", "火星")
        expect(ts.first["apex"]).to eq("火星")
      end

      it "allows a node to be the apex" do
        positions = { "北交點" => 90, "太陽" => 0, "月亮" => 180 }
        results = described_class.detect(positions)

        ts = of_type(results, "T三角")
        expect(ts.length).to eq(1)
        expect(ts.first["apex"]).to eq("北交點")
      end

      it "reports an opposition squared by the node axis once, with apex 北交點" do
        # 南交點 mirrors 北交點 exactly, so without collapsing this would
        # produce two identical T-squares (apex 北交點 and apex 南交點).
        positions = { "太陽" => 0, "火星" => 180, "北交點" => 90, "南交點" => 270 }
        results = described_class.detect(positions)

        expect(of_type(results, "大十字")).to be_empty
        ts = of_type(results, "T三角")
        expect(ts.length).to eq(1)
        expect(ts.first["apex"]).to eq("北交點")
        expect(ts.first["planets"]).to contain_exactly("太陽", "火星", "北交點")
      end

      it "keeps a 南交點 apex when there is no mirroring 北交點 apex" do
        # No 北交點 in the position set — the 南交點 T-square stands alone.
        positions = { "南交點" => 90, "太陽" => 0, "月亮" => 180 }
        results = described_class.detect(positions)

        ts = of_type(results, "T三角")
        expect(ts.length).to eq(1)
        expect(ts.first["apex"]).to eq("南交點")
      end
    end

    context "大十字 (Grand Cross)" do
      it "detects a grand cross and does not also report its T-squares" do
        positions = { "太陽" => 0, "月亮" => 92, "火星" => 183, "金星" => 268 }
        results = described_class.detect(positions)

        expect(results.length).to eq(1)
        cross = results.first
        expect(cross["pattern_type"]).to eq("大十字")
        expect(cross["planets"]).to contain_exactly("太陽", "月亮", "火星", "金星")
        expect(of_type(results, "T三角")).to be_empty
      end

      it "does not use the node axis as an opposition leg of a grand cross" do
        # 北-南 is excluded as an opposition leg, so only 火星-金星 remains:
        # no grand cross, and the node-axis square collapses to a single
        # T-square with apex 北交點 (the 南交點 twin is the same axis).
        positions = { "北交點" => 0, "南交點" => 180, "火星" => 90, "金星" => 270 }
        results = described_class.detect(positions)

        expect(of_type(results, "大十字")).to be_empty
        ts = of_type(results, "T三角")
        expect(ts.length).to eq(1)
        expect(ts.first["apex"]).to eq("北交點")
        expect(ts.first["planets"]).to contain_exactly("火星", "金星", "北交點")
      end

      it "still reports T-squares not subsumed by the cross" do
        # A grand cross plus a fully independent T-square (水星/土星 opposition
        # with 木星 apex); the standalone trio forms no aspects to cross bodies.
        positions = {
          "太陽" => 0, "月亮" => 92, "火星" => 183, "金星" => 268, # 大十字
          "水星" => 45, "土星" => 225, "木星" => 135               # 獨立 T三角
        }
        results = described_class.detect(positions)

        expect(of_type(results, "大十字").length).to eq(1)
        ts = of_type(results, "T三角")
        apexes = ts.map { |t| t["apex"] }
        expect(apexes).to include("木星")
        ts.each do |t|
          # No reported T-square may consist solely of the cross's bodies.
          expect((t["planets"] - ["太陽", "月亮", "火星", "金星"])).not_to be_empty
        end
      end
    end

    context "上帝之指 (Yod)" do
      it "detects a yod: sextile base with a quincunx apex" do
        # 太陽 0 六分相 金星 60; 火星 210 補十二分相 both (150° from each)
        positions = { "太陽" => 0, "金星" => 60, "火星" => 210 }
        results = described_class.detect(positions)

        yods = of_type(results, "上帝之指")
        expect(yods.length).to eq(1)
        expect(yods.first["planets"]).to contain_exactly("太陽", "金星", "火星")
        expect(yods.first["apex"]).to eq("火星")
      end

      it "does not fire without the quincunxes" do
        # sextile base only; third body forms no 150° legs
        positions = { "太陽" => 0, "金星" => 60, "火星" => 120 }
        expect(of_type(described_class.detect(positions), "上帝之指")).to be_empty
      end
    end

    context "風箏 (Kite)" do
      it "detects a kite over a grand trine and reports both" do
        # 大三角 太陽0/木星120/火星240; 月亮60 opposes 火星240, sextiles 太陽 & 木星
        positions = { "太陽" => 0, "木星" => 120, "火星" => 240, "月亮" => 60 }
        results = described_class.detect(positions)

        expect(of_type(results, "大三角").length).to eq(1)
        kites = of_type(results, "風箏")
        expect(kites.length).to eq(1)
        expect(kites.first["planets"]).to contain_exactly("太陽", "木星", "火星", "月亮")
        expect(kites.first["apex"]).to eq("月亮")
      end
    end

    context "神祕矩形 (Mystic Rectangle)" do
      it "detects two oppositions joined by sextiles and trines" do
        # 太陽0 對分 火星180; 金星60 對分 土星240; short sides sextile, long trine
        positions = { "太陽" => 0, "火星" => 180, "金星" => 60, "土星" => 240 }
        results = described_class.detect(positions)

        rects = of_type(results, "神祕矩形")
        expect(rects.length).to eq(1)
        expect(rects.first["planets"])
          .to contain_exactly("太陽", "火星", "金星", "土星")
      end

      it "does not treat a grand cross (square cross-links) as a rectangle" do
        positions = { "太陽" => 0, "月亮" => 92, "火星" => 183, "金星" => 268 }
        expect(of_type(described_class.detect(positions), "神祕矩形")).to be_empty
      end
    end

    context "星群 (Stellium)" do
      it "detects 3+ bodies sharing a sign" do
        # 太陽 5, 水星 12, 金星 25 all in 牡羊座 (0-30)
        positions = { "太陽" => 5, "水星" => 12, "金星" => 25, "火星" => 200 }
        results = described_class.detect(positions)

        stelliums = of_type(results, "星群")
        expect(stelliums.length).to eq(1)
        expect(stelliums.first["zodiac"]).to eq("牡羊座")
        expect(stelliums.first["planets"]).to contain_exactly("太陽", "水星", "金星")
      end

      it "does not fire on only two bodies in a sign" do
        positions = { "太陽" => 5, "水星" => 12, "火星" => 200 }
        expect(of_type(described_class.detect(positions), "星群")).to be_empty
      end
    end

    it "returns an empty array when no pattern is present" do
      # No pair here falls within any major aspect orb.
      positions = { "太陽" => 0, "月亮" => 40, "水星" => 200 }
      expect(described_class.detect(positions)).to eq([])
    end

    it "returns an empty array for fewer than 3 bodies" do
      expect(described_class.detect({ "太陽" => 0, "月亮" => 180 })).to eq([])
      expect(described_class.detect({})).to eq([])
    end
  end
end
