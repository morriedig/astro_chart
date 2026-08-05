require_relative "zodiac"

module AstroChart
  # Essential dignities (必然尊貴) — the classical Hellenistic / medieval
  # scheme of five dignities and their planetary rulers, plus the two major
  # debilities. Pure lookup tables; no ephemeris, fully deterministic.
  #
  # Rulers are the SEVEN traditional planets (太陽 月亮 水星 金星 火星 木星 土星).
  # These use the TRADITIONAL rulerships (天蠍→火星, 水瓶→土星, 雙魚→木星), which
  # differ from the modern rulers in Zodiac.ruler (冥王星/天王星/海王星). Dignity
  # theory predates the outer planets, so it is defined on the traditional set.
  #
  # The five dignities and their scores (Lilly / Ptolemaic weighting):
  #   廟 domicile     +5   planet rules the sign
  #   旺 exaltation   +4   planet is exalted in the sign (with an exact degree)
  #   三分性 triplicity +3   planet rules the sign's element by sect
  #   界 term/bound   +2   planet rules the bound the degree falls in
  #   外觀 face/decan  +1   planet rules the 10° face the degree falls in
  # Debilities: 陷 detriment (−5, opposite domicile), 弱 fall (−4, opposite
  # exaltation).
  #
  # Terms: 埃及界 (Egyptian, the default and most widely used) is verified and
  # supported. Other schemes (e.g. 托勒密界 / Ptolemaic) are not yet bundled —
  # the Ptolemaic table is textually disputed and awaits a verified source.
  module Dignities
    PLANETS = ["太陽", "月亮", "水星", "金星", "火星", "木星", "土星"].freeze

    # 傳統守護星 (traditional domicile rulers), by sign.
    DOMICILE = {
      "牡羊座" => "火星", "金牛座" => "金星", "雙子座" => "水星", "巨蟹座" => "月亮",
      "獅子座" => "太陽", "處女座" => "水星", "天秤座" => "金星", "天蠍座" => "火星",
      "射手座" => "木星", "摩羯座" => "土星", "水瓶座" => "土星", "雙魚座" => "木星",
    }.freeze

    # 旺 (exaltation): sign => [planet, exact degree]. Signs without an
    # exaltation ruler are absent.
    EXALTATION = {
      "牡羊座" => ["太陽", 19], "金牛座" => ["月亮", 3],  "巨蟹座" => ["木星", 15],
      "處女座" => ["水星", 15], "天秤座" => ["土星", 21], "摩羯座" => ["火星", 28],
      "雙魚座" => ["金星", 27],
    }.freeze

    # 三分性 (triplicity), Dorothean scheme: element => day/night/participating
    # rulers. Elements repeat every 4 signs from 牡羊 (火).
    ELEMENTS = ["火", "土", "風", "水"].freeze
    TRIPLICITY = {
      "火" => { day: "太陽", night: "木星", participating: "土星" },
      "土" => { day: "金星", night: "月亮", participating: "火星" },
      "風" => { day: "土星", night: "水星", participating: "木星" },
      "水" => { day: "金星", night: "火星", participating: "月亮" },
    }.freeze

    # 埃及界 (Egyptian terms): sign => [[ruler, ending_degree], ...5], the
    # ending degree measured within the sign (0-30). Verified against multiple
    # references.
    EGYPTIAN_TERMS = {
      "牡羊座" => [["木星", 6], ["金星", 12], ["水星", 20], ["火星", 25], ["土星", 30]],
      "金牛座" => [["金星", 8], ["水星", 14], ["木星", 22], ["土星", 27], ["火星", 30]],
      "雙子座" => [["水星", 6], ["木星", 12], ["金星", 17], ["火星", 24], ["土星", 30]],
      "巨蟹座" => [["火星", 7], ["金星", 13], ["水星", 19], ["木星", 26], ["土星", 30]],
      "獅子座" => [["木星", 6], ["金星", 11], ["土星", 18], ["水星", 24], ["火星", 30]],
      "處女座" => [["水星", 7], ["金星", 17], ["木星", 21], ["火星", 28], ["土星", 30]],
      "天秤座" => [["土星", 6], ["水星", 14], ["木星", 21], ["金星", 28], ["火星", 30]],
      "天蠍座" => [["火星", 7], ["金星", 11], ["水星", 19], ["木星", 24], ["土星", 30]],
      "射手座" => [["木星", 12], ["金星", 17], ["水星", 21], ["土星", 26], ["火星", 30]],
      "摩羯座" => [["水星", 7], ["木星", 14], ["金星", 22], ["土星", 26], ["火星", 30]],
      "水瓶座" => [["水星", 7], ["金星", 13], ["木星", 20], ["火星", 25], ["土星", 30]],
      "雙魚座" => [["金星", 12], ["木星", 16], ["水星", 19], ["火星", 28], ["土星", 30]],
    }.freeze

    TERM_SCHEMES = { egyptian: EGYPTIAN_TERMS }.freeze

    # 外觀 (faces / decans), Chaldean order: the 36 faces cycle the seven
    # planets in Chaldean sequence (土木火日金水月) starting at 火星 for 牡羊 0°.
    # Generated rather than tabulated — face n = CHALDEAN[(⌊lon/10⌋) mod 7].
    CHALDEAN_FROM_MARS = ["火星", "太陽", "金星", "水星", "月亮", "土星", "木星"].freeze

    DIGNITY_SCORES = { domicile: 5, exaltation: 4, triplicity: 3, term: 2, face: 1 }.freeze

    module_function

    def sign_of(longitude)
      Zodiac.sign_name(longitude)
    end

    def element_of(longitude)
      ELEMENTS[((longitude % 360).floor / 30) % 4]
    end

    # Degree within the current sign (0-30).
    def degree_in_sign(longitude)
      (longitude % 360.0) % 30.0
    end

    # +5 ruler of the sign (traditional).
    def domicile_ruler(longitude)
      DOMICILE[sign_of(longitude)]
    end

    # −5 planet in detriment here = ruler of the opposite sign.
    def detriment_ruler(longitude)
      DOMICILE[sign_of(longitude + 180.0)]
    end

    # +4 exalted planet in this sign, or nil.
    def exaltation_ruler(longitude)
      entry = EXALTATION[sign_of(longitude)]
      entry && entry[0]
    end

    # −4 planet in fall here = the planet exalted in the opposite sign, or nil.
    def fall_ruler(longitude)
      entry = EXALTATION[sign_of(longitude + 180.0)]
      entry && entry[0]
    end

    # Triplicity rulers for the sign's element.
    # Returns { day:, night:, participating: }.
    def triplicity_rulers(longitude)
      TRIPLICITY[element_of(longitude)]
    end

    # +3 triplicity ruler active for the given sect (:day / :night).
    def triplicity_ruler(longitude, sect: :day)
      trip = triplicity_rulers(longitude)
      sect == :night ? trip[:night] : trip[:day]
    end

    # +2 term/bound ruler at this degree (Egyptian by default).
    def term_ruler(longitude, scheme: :egyptian)
      table = TERM_SCHEMES[scheme]
      unless table
        raise ArgumentError,
              "unknown term scheme #{scheme.inspect} (available: #{TERM_SCHEMES.keys.inspect})"
      end
      deg = degree_in_sign(longitude)
      table[sign_of(longitude)].each do |ruler, ending|
        return ruler if deg < ending
      end
      table[sign_of(longitude)].last[0] # exactly 30.0 → last term
    end

    # +1 face/decan ruler at this degree (Chaldean order).
    def face_ruler(longitude)
      CHALDEAN_FROM_MARS[((longitude % 360).floor / 10) % 7]
    end

    # Total essential-dignity score a planet holds at a longitude (sum of the
    # positive dignities it rules). Debilities are reported separately by .of
    # and are not subtracted here.
    def score(planet, longitude, sect: :day, terms: :egyptian)
      total = 0
      total += DIGNITY_SCORES[:domicile]   if domicile_ruler(longitude) == planet
      total += DIGNITY_SCORES[:exaltation] if exaltation_ruler(longitude) == planet
      total += DIGNITY_SCORES[:triplicity] if triplicity_ruler(longitude, sect: sect) == planet
      total += DIGNITY_SCORES[:term]       if term_ruler(longitude, scheme: terms) == planet
      total += DIGNITY_SCORES[:face]       if face_ruler(longitude) == planet
      total
    end

    # Full dignity/debility report for a planet at a longitude.
    #
    #   { "dignities" => ["廟", "界"...], "debilities" => ["陷"...],
    #     "score" => 7 }
    #
    # Exaltation/fall are placement dignities of the sign (the exact degree is
    # the peak but the whole sign confers the dignity), matching Lilly's table.
    def of(planet, longitude, sect: :day, terms: :egyptian)
      dignities = []
      dignities << "廟"   if domicile_ruler(longitude) == planet
      dignities << "旺"   if exaltation_ruler(longitude) == planet
      dignities << "三分性" if triplicity_ruler(longitude, sect: sect) == planet
      dignities << "界"   if term_ruler(longitude, scheme: terms) == planet
      dignities << "外觀" if face_ruler(longitude) == planet

      debilities = []
      debilities << "陷" if detriment_ruler(longitude) == planet
      debilities << "弱" if fall_ruler(longitude) == planet

      {
        "planet"     => planet,
        "dignities"  => dignities,
        "debilities" => debilities,
        "score"      => score(planet, longitude, sect: sect, terms: terms),
      }
    end

    # Almuten of a degree (界主星/度數勝利星): the traditional planet with the
    # highest total dignity score at that longitude. Returns
    #   { "planet" => "火星", "score" => 7, "tied" => ["火星", ...] }
    # `tied` lists every planet sharing the top score (usually one).
    def almuten(longitude, sect: :day, terms: :egyptian)
      scored = PLANETS.map { |p| [p, score(p, longitude, sect: sect, terms: terms)] }
      top = scored.map { |_p, s| s }.max
      winners = scored.select { |_p, s| s == top }.map { |p, _s| p }
      { "planet" => winners.first, "score" => top, "tied" => winners }
    end
  end
end
