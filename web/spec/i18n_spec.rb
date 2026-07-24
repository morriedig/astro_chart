require_relative "spec_helper"

RSpec.describe "API i18n" do
  def app
    AstroWeb
  end

  TAIPEI_PARAMS = {
    "birth_date" => "1990-01-01",
    "birth_time" => "12:00",
    "latitude" => 25.033,
    "longitude" => 121.5654,
    "timezone" => "Asia/Taipei",
  }.freeze

  TOKYO_PARAMS = {
    "birth_date" => "1985-06-15",
    "birth_time" => "08:30",
    "latitude" => 35.6762,
    "longitude" => 139.6503,
    "timezone" => "Asia/Tokyo",
  }.freeze

  SUN_NAME = { "en" => "Sun", "ja" => "太陽", "ko" => "태양" }.freeze
  CAPRICORN = { "en" => "Capricorn", "ja" => "山羊座", "ko" => "염소자리" }.freeze
  ASPECT_NAMES = {
    "en" => ["Conjunction", "Sextile", "Square", "Trine", "Opposition"],
    "ja" => ["コンジャンクション", "セクスタイル", "スクエア", "トライン", "オポジション"],
    "ko" => ["컨정션", "섹스타일", "스퀘어", "트라인", "어포지션"],
  }.freeze
  ELEMENT_KEYS = {
    "en" => %w[Fire Earth Air Water],
    "ja" => %w[火 地 風 水],
    "ko" => %w[불 흙 공기 물],
  }.freeze
  MODALITY_KEYS = {
    "en" => %w[Cardinal Fixed Mutable],
    "ja" => %w[活動 不動 柔軟],
    "ko" => %w[활동궁 고정궁 변통궁],
  }.freeze
  PLANET_NAMES = {
    "en" => [
      "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn",
      "Uranus", "Neptune", "Pluto", "North Node", "South Node",
      "Part of Fortune", "Lilith",
      "North Node Ruler", "South Node Ruler", "Ascendant Ruler",
    ],
    "ja" => [
      "太陽", "月", "水星", "金星", "火星", "木星", "土星",
      "天王星", "海王星", "冥王星", "ドラゴンヘッド", "ドラゴンテイル",
      "パート・オブ・フォーチュン", "リリス",
      "ドラゴンヘッドの支配星", "ドラゴンテイルの支配星", "アセンダントの支配星",
    ],
    "ko" => [
      "태양", "달", "수성", "금성", "화성", "목성", "토성",
      "천왕성", "해왕성", "명왕성", "북교점", "남교점",
      "포르투나", "릴리트",
      "북교점 지배성", "남교점 지배성", "상승궁 지배성",
    ],
  }.freeze

  def post_json(path, payload)
    body = payload.is_a?(String) ? payload : JSON.generate(payload)
    post path, body, "CONTENT_TYPE" => "application/json"
  end

  def parsed_body
    JSON.parse(last_response.body)
  end

  describe "lang normalization" do
    it "accepts zh / zh_tw / zh-tw case-insensitively as zh-TW" do
      ["zh", "ZH_TW", "zh-tw", "Zh-TW"].each do |alias_value|
        post_json "/api/v1/charts", TAIPEI_PARAMS.merge("lang" => alias_value)
        expect(last_response.status).to eq(200)
        sun = parsed_body.dig("data", "chart", "planets").first
        expect(sun.fetch("planet")).to eq("太陽")
      end
    end

    it "accepts EN case-insensitively" do
      post_json "/api/v1/charts", TAIPEI_PARAMS.merge("lang" => "EN")
      expect(last_response.status).to eq(200)
      expect(parsed_body.dig("data", "chart", "planets").first.fetch("planet")).to eq("Sun")
    end

    it "returns 400 invalid_lang for an unsupported lang on a POST endpoint" do
      post_json "/api/v1/charts", TAIPEI_PARAMS.merge("lang" => "fr")
      expect(last_response.status).to eq(400)
      expect(parsed_body.dig("error", "code")).to eq("invalid_lang")
      expect(parsed_body.dig("error", "message")).to include("fr")
    end

    it "returns 400 invalid_lang for a non-string lang" do
      post_json "/api/v1/charts", TAIPEI_PARAMS.merge("lang" => 42)
      expect(last_response.status).to eq(400)
      expect(parsed_body.dig("error", "code")).to eq("invalid_lang")
    end

    it "returns 400 invalid_lang on GET /api/v1/cities" do
      get "/api/v1/cities", "q" => "taipei", "lang" => "de"
      expect(last_response.status).to eq(400)
      expect(parsed_body.dig("error", "code")).to eq("invalid_lang")
    end
  end

  describe "zh-TW regression" do
    it "keeps the lang-less response byte-identical to an explicit zh-TW request" do
      post_json "/api/v1/charts", TAIPEI_PARAMS
      without_lang = last_response.body
      post_json "/api/v1/charts", TAIPEI_PARAMS.merge("lang" => "zh-TW")
      expect(last_response.body).to eq(without_lang)
    end

    it "keeps zh-TW vocabulary untouched without lang" do
      post_json "/api/v1/charts", TAIPEI_PARAMS
      chart = parsed_body.dig("data", "chart")
      sun = chart.fetch("planets").first
      expect(sun.fetch("planet")).to eq("太陽")
      expect(sun.fetch("zodiac")).to eq("摩羯座")
      expect(chart.dig("element_stats", "elements").keys).to eq(%w[火 土 風 水])
      expect(chart.dig("element_stats", "modalities").keys).to eq(%w[基本 固定 變動])
    end

    it "keeps zh-TW error messages untouched without lang" do
      post_json "/api/v1/charts", TAIPEI_PARAMS.merge("timezone" => "Asia/NotAPlace")
      expect(parsed_body.dig("error", "message")).to eq("無效的時區識別碼：Asia/NotAPlace")
    end
  end

  describe "POST /api/v1/charts localization" do
    %w[en ja ko].each do |lang|
      context "lang #{lang}" do
        before { post_json "/api/v1/charts", TAIPEI_PARAMS.merge("lang" => lang) }

        it "translates all 17 planet names in order" do
          planets = parsed_body.dig("data", "chart", "planets")
          expect(planets.map { |p| p["planet"] }).to eq(PLANET_NAMES.fetch(lang))
        end

        it "translates the Sun's zodiac to #{CAPRICORN[lang]}" do
          sun = parsed_body.dig("data", "chart", "planets").first
          expect(sun.fetch("zodiac")).to eq(CAPRICORN.fetch(lang))
        end

        it "translates aspect_type values" do
          aspects = parsed_body.dig("data", "chart", "planets").flat_map { |p| p["aspects"] || [] }
          expect(aspects).not_to be_empty
          expect(ASPECT_NAMES.fetch(lang))
            .to include(*aspects.map { |a| a["aspect_type"] }.uniq)
        end

        it "translates element_stats keys and preserves the counts" do
          stats = parsed_body.dig("data", "chart", "element_stats")
          expect(stats.fetch("elements").keys).to eq(ELEMENT_KEYS.fetch(lang))
          expect(stats.fetch("modalities").keys).to eq(MODALITY_KEYS.fetch(lang))
          expect(stats.fetch("elements").values.sum).to eq(10)
          expect(stats.fetch("modalities").values.sum).to eq(10)
        end

        it "leaves the input echo untranslated" do
          expect(parsed_body.dig("data", "input")).to eq(
            "birth_date" => "1990-01-01",
            "birth_time" => "12:00",
            "coordinates" => { "latitude" => 25.033, "longitude" => 121.5654 },
            "timezone" => "Asia/Taipei"
          )
        end

        it "keeps the house_system code and numbers untouched" do
          chart = parsed_body.dig("data", "chart")
          expect(chart.fetch("house_system")).to eq("P")
          expect(chart.dig("ascendant", "total_degree")).to be_a(Numeric)
        end
      end
    end
  end

  describe "patterns translation (I18n.translate_payload)" do
    let(:patterns) do
      {
        "patterns" => [
          { "pattern_type" => "大三角", "planets" => ["太陽", "月亮", "火星"], "element" => "火" },
          { "pattern_type" => "T三角", "planets" => ["金星", "土星", "冥王星"], "apex" => "冥王星" },
          { "pattern_type" => "大十字", "planets" => ["水星", "木星", "天王星", "海王星"] },
        ],
      }
    end

    it "translates pattern_type, planets, apex and element to en" do
      out = I18n.translate_payload(patterns, "en").fetch("patterns")
      expect(out[0]).to eq(
        "pattern_type" => "Grand Trine", "planets" => %w[Sun Moon Mars], "element" => "Fire"
      )
      expect(out[1]).to eq(
        "pattern_type" => "T-Square", "planets" => %w[Venus Saturn Pluto], "apex" => "Pluto"
      )
      expect(out[2].fetch("pattern_type")).to eq("Grand Cross")
    end

    it "translates pattern vocabulary to ja and ko" do
      ja = I18n.translate_payload(patterns, "ja").fetch("patterns")
      expect(ja.map { |p| p["pattern_type"] }).to eq(["グランドトライン", "Tスクエア", "グランドクロス"])
      expect(ja[0].fetch("planets")).to eq(["太陽", "月", "火星"])
      ko = I18n.translate_payload(patterns, "ko").fetch("patterns")
      expect(ko.map { |p| p["pattern_type"] }).to eq(["그랜드 트라인", "T 스퀘어", "그랜드 크로스"])
      expect(ko[1].fetch("apex")).to eq("명왕성")
    end

    it "keeps a nil element as nil" do
      nil_element = { "patterns" => [{ "pattern_type" => "大三角", "planets" => [], "element" => nil }] }
      out = I18n.translate_payload(nil_element, "en")
      expect(out.dig("patterns", 0, "element")).to be_nil
    end
  end

  describe "POST /api/v1/synastry localization" do
    before do
      post_json "/api/v1/synastry",
                "a" => TAIPEI_PARAMS, "b" => TOKYO_PARAMS, "orb_limit" => 6.0, "lang" => "en"
    end

    it "translates house-overlay hash keys to planet names" do
      %w[a_planets_in_b_houses b_planets_in_a_houses].each do |key|
        overlay = parsed_body.dig("data", "synastry", key)
        expect(overlay.keys).to include("Sun", "Moon")
        expect(overlay.keys).to all(match(/\A[A-Za-z ]+\z/))
        expect(overlay.values).to all(be_between(1, 12))
      end
    end

    it "translates a_planet / b_planet / aspect_type in cross aspects" do
      aspects = parsed_body.dig("data", "synastry", "aspects")
      expect(aspects).not_to be_empty
      aspects.each do |aspect|
        expect(aspect.fetch("a_planet")).to match(/\A[A-Za-z ]+\z/)
        expect(aspect.fetch("b_planet")).to match(/\A[A-Za-z ]+\z/)
        expect(ASPECT_NAMES.fetch("en")).to include(aspect.fetch("aspect_type"))
      end
    end

    it "translates both embedded charts too" do
      %w[a_chart b_chart].each do |key|
        expect(parsed_body.dig("data", key, "chart", "planets").first.fetch("planet")).to eq("Sun")
      end
    end
  end

  describe "POST /api/v1/transits localization" do
    before do
      post_json "/api/v1/transits",
                "natal" => TAIPEI_PARAMS, "lang" => "ja",
                "at" => { "date" => "2026-07-24", "time" => "12:00", "timezone" => "Asia/Taipei" }
    end

    it "translates transiting planet names and zodiac (late-July Sun in 獅子座)" do
      sun = parsed_body.dig("data", "planets").find { |p| p["planet"] == "太陽" }
      expect(sun).not_to be_nil
      expect(sun.fetch("zodiac")).to eq("獅子座")
      moon = parsed_body.dig("data", "planets").find { |p| p["planet"] == "月" }
      expect(moon).not_to be_nil
    end

    it "translates transit_planet / natal_planet / aspect_type in aspects" do
      aspects = parsed_body.dig("data", "aspects")
      expect(aspects).not_to be_empty
      expect(ASPECT_NAMES.fetch("ja")).to include(*aspects.map { |a| a["aspect_type"] }.uniq)
      names = aspects.flat_map { |a| [a["transit_planet"], a["natal_planet"]] }.uniq
      expect(PLANET_NAMES.fetch("ja")).to include(*names)
    end
  end

  describe "POST /api/v1/progressions localization" do
    before do
      post_json "/api/v1/progressions",
                "natal" => TAIPEI_PARAMS, "target_date" => "2020-01-01", "lang" => "ko"
    end

    it "translates progressed planet names and zodiac (Sun into 물병자리)" do
      prog_sun = parsed_body.dig("data", "progression", "planets")
                            .find { |p| p["planet"] == "태양" }
      expect(prog_sun).not_to be_nil
      expect(prog_sun.fetch("zodiac")).to eq("물병자리")
    end

    it "translates progressed_planet / natal_planet in aspects_to_natal" do
      aspects = parsed_body.dig("data", "progression", "aspects_to_natal")
      names = aspects.flat_map { |a| [a["progressed_planet"], a["natal_planet"]] }.uniq
      expect(PLANET_NAMES.fetch("ko")).to include(*names)
      expect(ASPECT_NAMES.fetch("ko")).to include(*aspects.map { |a| a["aspect_type"] }.uniq)
    end
  end

  describe "POST /api/v1/composite localization" do
    before do
      post_json "/api/v1/composite",
                "a" => TAIPEI_PARAMS, "b" => TOKYO_PARAMS, "lang" => "en"
    end

    it "translates composite planet names and zodiac values" do
      planets = parsed_body.dig("data", "composite", "planets")
      expect(PLANET_NAMES.fetch("en")).to include(*planets.map { |p| p["planet"] }.uniq)
      zodiac_en = %w[Aries Taurus Gemini Cancer Leo Virgo Libra Scorpio
                     Sagittarius Capricorn Aquarius Pisces]
      expect(zodiac_en).to include(*planets.map { |p| p["zodiac"] }.uniq)
    end

    it "translates planet_a / planet_b / aspect_type in composite aspects" do
      aspects = parsed_body.dig("data", "composite", "aspects")
      names = aspects.flat_map { |a| [a["planet_a"], a["planet_b"]] }.uniq
      expect(PLANET_NAMES.fetch("en")).to include(*names)
      expect(ASPECT_NAMES.fetch("en")).to include(*aspects.map { |a| a["aspect_type"] }.uniq)
    end
  end

  describe "POST /api/v1/solar-return localization" do
    before do
      post_json "/api/v1/solar-return",
                "natal" => TAIPEI_PARAMS, "year" => 2026, "lang" => "en"
    end

    it "translates the solar-return chart and keeps its numbers" do
      sr_sun = parsed_body.dig("data", "solar_return", "chart", "planets").first
      expect(sr_sun.fetch("planet")).to eq("Sun")
      expect(sr_sun.fetch("zodiac")).to eq("Capricorn")
      expect(sr_sun.fetch("total_degree")).to be_a(Numeric)
    end

    it "translates the natal chart in the same response" do
      expect(parsed_body.dig("data", "natal_chart", "chart", "planets").first.fetch("planet")).to eq("Sun")
    end
  end

  describe "GET /api/v1/cities localization" do
    it "keeps 中文 name and country for zh-TW (default)" do
      get "/api/v1/cities", "q" => "taipei"
      expect(parsed_body.fetch("data").first).to include("name" => "台北市", "country" => "台灣")
    end

    %w[en ja ko].each do |lang|
      it "uses the primary English name and English country for #{lang}" do
        get "/api/v1/cities", "q" => "tokyo", "lang" => lang
        city = parsed_body.fetch("data").first
        expect(city).to include("name" => "Tokyo", "country" => "Japan")
        expect(city).to include("latitude" => 35.6762, "longitude" => 139.6503,
                                "timezone" => "Asia/Tokyo")
      end
    end

    it "keeps matching behavior unchanged under a lang" do
      get "/api/v1/cities", "q" => "lon", "lang" => "en"
      names = parsed_body.fetch("data").map { |c| c["name"] }
      expect(names.first).to eq("London")
      expect(names).to include("Barcelona")
    end

    it "never exposes the alt key under a lang" do
      get "/api/v1/cities", "q" => "taipei", "lang" => "en"
      expect(parsed_body.fetch("data")).to all(satisfy { |c| !c.key?("alt") })
    end
  end

  describe "localized error messages" do
    it "returns the invalid_timezone message in English" do
      post_json "/api/v1/charts",
                TAIPEI_PARAMS.merge("timezone" => "Asia/NotAPlace", "lang" => "en")
      expect(last_response.status).to eq(400)
      error = parsed_body.fetch("error")
      expect(error.fetch("code")).to eq("invalid_timezone")
      expect(error.fetch("message")).to eq("Invalid timezone identifier: Asia/NotAPlace")
    end

    it "returns the missing_param message in Japanese" do
      post_json "/api/v1/charts",
                TAIPEI_PARAMS.reject { |k, _| k == "birth_time" }.merge("lang" => "ja")
      error = parsed_body.fetch("error")
      expect(error.fetch("code")).to eq("missing_param")
      expect(error.fetch("message")).to eq("パラメータが不足しています：birth_time")
    end

    it "returns the missing q message in Korean on /api/v1/cities" do
      get "/api/v1/cities", "lang" => "ko"
      error = parsed_body.fetch("error")
      expect(error.fetch("code")).to eq("missing_param")
      expect(error.fetch("message")).to eq("누락된 매개변수: q")
    end

    it "keeps error codes language-independent" do
      post_json "/api/v1/charts",
                TAIPEI_PARAMS.merge("latitude" => 95, "lang" => "en")
      expect(parsed_body.dig("error", "code")).to eq("invalid_coordinates")
      expect(parsed_body.dig("error", "message")).to include("±90")
    end
  end
end
