module AstroChart
  # Element (四大元素) and modality (三大模式) distribution statistics.
  #
  # Both classifications follow directly from the zodiac sign a body
  # occupies. Starting from 牡羊座, elements repeat every 4 signs
  # (火土風水) and modalities every 3 signs (基本固定變動):
  #
  #   牡羊=火基本  金牛=土固定  雙子=風變動  巨蟹=水基本
  #   獅子=火固定  處女=土變動  天秤=風基本  天蠍=水固定
  #   射手=火變動  摩羯=土基本  水瓶=風固定  雙魚=水變動
  module Stats
    ELEMENTS = ["火", "土", "風", "水"].freeze
    MODALITIES = ["基本", "固定", "變動"].freeze

    # positions: { "太陽" => 123.45, ... } — the 10 classical planets
    # (太陽..冥王星); the caller is responsible for passing only those.
    #
    # Returns:
    #   { "elements"   => { "火" => n, "土" => n, "風" => n, "水" => n },
    #     "modalities" => { "基本" => n, "固定" => n, "變動" => n } }
    def self.elements(positions)
      element_counts = ELEMENTS.to_h { |e| [e, 0] }
      modality_counts = MODALITIES.to_h { |m| [m, 0] }

      positions.each_value do |degree|
        sign_index = (degree % 360).floor / 30
        element_counts[ELEMENTS[sign_index % 4]] += 1
        modality_counts[MODALITIES[sign_index % 3]] += 1
      end

      { "elements" => element_counts, "modalities" => modality_counts }
    end
  end
end
