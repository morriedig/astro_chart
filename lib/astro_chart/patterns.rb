require_relative "aspects"

module AstroChart
  # Aspect pattern detection (相位圖形).
  #
  # Detects the three classic configurations from a set of ecliptic
  # longitudes (相位由 Aspects.calculate 重新計算，不依賴外部相位表):
  #
  #   大三角 (Grand Trine): 3 bodies pairwise in 三分相.
  #   T三角  (T-Square):    2 bodies in 對分相, both 四分相 to an apex.
  #   大十字 (Grand Cross): 4 bodies forming 2 對分相 pairs with all 4
  #                         adjacent pairs in 四分相.
  #
  # Deduplication rules:
  #   - A 大十字 subsumes the 4 T三角s formed by its own bodies — those
  #     T三角s are not reported separately.
  #   - 南交點 sits exactly 180° from 北交點, so an opposition squared by
  #     the node axis would always yield two mirrored T三角s (apex 北交點
  #     and apex 南交點). The 南交點-apex twin is collapsed: the single
  #     physical configuration is reported once, with apex 北交點.
  #   - Each pattern is reported once regardless of body order.
  module Patterns
    # Elements repeat every 4 signs starting from 牡羊座 (火).
    ELEMENTS = ["火", "土", "風", "水"].freeze

    # 北交點/南交點 are always exactly 180° apart by definition, so their
    # mutual 對分相 carries no astrological information. That specific pair
    # is therefore excluded from serving as the opposition leg of a T三角
    # or 大十字. The nodes themselves remain valid participants — e.g. a
    # node may still be the apex of a T三角, or oppose a planet.
    NODE_AXIS = ["北交點", "南交點"].sort.freeze

    # positions: { "太陽" => 123.45, ... } (ecliptic longitudes, degrees)
    #
    # Returns Array of:
    #   { "pattern_type" => "大三角", "planets" => [...], "element" => "火" | nil }
    #   { "pattern_type" => "T三角",  "planets" => [...], "apex" => "火星" }
    #   { "pattern_type" => "大十字", "planets" => [...] }
    def self.detect(positions)
      names = positions.keys
      trines = {}
      squares = {}
      oppositions = {}

      names.combination(2) do |a, b|
        type, _orb = Aspects.calculate(positions[a], positions[b])
        case type
        when "三分相" then trines[[a, b].sort] = true
        when "四分相" then squares[[a, b].sort] = true
        when "對分相" then oppositions[[a, b].sort] = true
        end
      end

      # See NODE_AXIS: the definitional node opposition never counts as
      # the opposition leg of a T三角 or 大十字.
      oppositions.delete(NODE_AXIS)

      grand_trines = detect_grand_trines(names, trines, positions)
      grand_crosses = detect_grand_crosses(oppositions, squares)
      t_squares = detect_t_squares(names, oppositions, squares)

      # 大十字 subsumes its own 4 T三角s.
      cross_sets = grand_crosses.map { |gc| gc["planets"] }
      t_squares = t_squares.reject do |t|
        cross_sets.any? { |set| (t["planets"] - set).empty? }
      end

      # See NODE_AXIS: a 南交點-apex T三角 mirroring a 北交點-apex one on
      # the same opposition is the same physical configuration ("opposition
      # squared by the node axis") — report it once, with apex 北交點.
      t_squares = t_squares.reject do |t|
        t["apex"] == "南交點" &&
          t_squares.any? do |other|
            other["apex"] == "北交點" && other["planets"][0, 2] == t["planets"][0, 2]
          end
      end

      grand_trines + t_squares + grand_crosses
    end

    def self.detect_grand_trines(names, trines, positions)
      names.combination(3).each_with_object([]) do |(a, b, c), out|
        next unless pair?(trines, a, b) && pair?(trines, a, c) && pair?(trines, b, c)

        elements = [a, b, c].map { |n| element_of(positions[n]) }
        out << {
          "pattern_type" => "大三角",
          "planets"      => [a, b, c],
          "element"      => elements.uniq.length == 1 ? elements.first : nil,
        }
      end
    end

    def self.detect_t_squares(names, oppositions, squares)
      oppositions.keys.each_with_object([]) do |(a, b), out|
        names.each do |apex|
          next if apex == a || apex == b
          next unless pair?(squares, apex, a) && pair?(squares, apex, b)

          out << {
            "pattern_type" => "T三角",
            "planets"      => [a, b, apex],
            "apex"         => apex,
          }
        end
      end
    end

    def self.detect_grand_crosses(oppositions, squares)
      found = {}
      oppositions.keys.combination(2) do |(a, b), (c, d)|
        next unless ([a, b] & [c, d]).empty?
        next unless pair?(squares, a, c) && pair?(squares, a, d) &&
                    pair?(squares, b, c) && pair?(squares, b, d)

        found[[a, b, c, d].sort] ||= {
          "pattern_type" => "大十字",
          "planets"      => [a, b, c, d],
        }
      end
      found.values
    end

    def self.pair?(store, a, b)
      store.key?([a, b].sort)
    end

    def self.element_of(degree)
      ELEMENTS[((degree % 360).floor / 30) % 4]
    end

    private_class_method :detect_grand_trines, :detect_t_squares,
                         :detect_grand_crosses, :pair?, :element_of
  end
end
