require "spec_helper"
require "astro_chart/stats"

RSpec.describe AstroChart::Stats do
  describe ".elements" do
    it "counts elements and modalities for a hand-built 10-planet chart" do
      positions = {
        "太陽"   => 5,    # 牡羊 火/基本
        "月亮"   => 35,   # 金牛 土/固定
        "水星"   => 65,   # 雙子 風/變動
        "金星"   => 95,   # 巨蟹 水/基本
        "火星"   => 125,  # 獅子 火/固定
        "木星"   => 155,  # 處女 土/變動
        "土星"   => 185,  # 天秤 風/基本
        "天王星" => 215,  # 天蠍 水/固定
        "海王星" => 245,  # 射手 火/變動
        "冥王星" => 275,  # 摩羯 土/基本
      }

      result = described_class.elements(positions)

      expect(result["elements"]).to eq(
        "火" => 3, "土" => 3, "風" => 2, "水" => 2
      )
      expect(result["modalities"]).to eq(
        "基本" => 4, "固定" => 3, "變動" => 3
      )
    end

    it "covers the remaining signs (水瓶/雙魚)" do
      positions = {
        "太陽" => 305, # 水瓶 風/固定
        "月亮" => 335, # 雙魚 水/變動
      }

      result = described_class.elements(positions)

      expect(result["elements"]).to eq(
        "火" => 0, "土" => 0, "風" => 1, "水" => 1
      )
      expect(result["modalities"]).to eq(
        "基本" => 0, "固定" => 1, "變動" => 1
      )
    end

    it "puts all counts in one bucket when every planet shares a sign" do
      positions = (1..10).to_h { |i| ["planet#{i}", 210.0 + i] } # 天蠍

      result = described_class.elements(positions)

      expect(result["elements"]).to eq(
        "火" => 0, "土" => 0, "風" => 0, "水" => 10
      )
      expect(result["modalities"]).to eq(
        "基本" => 0, "固定" => 10, "變動" => 0
      )
    end

    it "normalizes degrees outside 0-360" do
      positions = {
        "太陽" => 360.0,  # → 0 牡羊 火/基本
        "月亮" => 359.9,  # 雙魚 水/變動
        "水星" => -10.0,  # → 350 雙魚 水/變動
      }

      result = described_class.elements(positions)

      expect(result["elements"]).to eq(
        "火" => 1, "土" => 0, "風" => 0, "水" => 2
      )
      expect(result["modalities"]).to eq(
        "基本" => 1, "固定" => 0, "變動" => 2
      )
    end

    it "returns zeroed buckets for empty input" do
      result = described_class.elements({})

      expect(result).to eq(
        "elements"   => { "火" => 0, "土" => 0, "風" => 0, "水" => 0 },
        "modalities" => { "基本" => 0, "固定" => 0, "變動" => 0 }
      )
    end
  end
end
