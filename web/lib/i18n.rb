require_relative "cities"

# API-layer i18n for the AstroWeb JSON API.
#
# The astro_chart gem emits Traditional-Chinese (zh-TW) vocabulary values
# (planet / zodiac / aspect / pattern / element names). This module maps
# those values — and the API error messages — into en / ja / ko at the
# response boundary. zh-TW is the default and is a strict no-op, so the
# lang-less behavior stays byte-identical.
#
# Public interface:
#   I18n.normalize_lang(raw)                    -> "zh-TW"/"en"/"ja"/"ko" or nil
#   I18n.translate_payload(obj, lang)           -> deep-translated copy
#   I18n.error_message(key, lang, fallback, args) -> localized error string
#   I18n.localize_cities(results, lang)         -> localized city rows
module I18n
  DEFAULT_LANG = "zh-TW".freeze
  SUPPORTED_LANGS = ["zh-TW", "en", "ja", "ko"].freeze

  # Case-insensitive aliases (downcased) -> canonical lang.
  LANG_ALIASES = {
    "zh-tw" => "zh-TW",
    "zh_tw" => "zh-TW",
    "zh"    => "zh-TW",
    "en"    => "en",
    "ja"    => "ja",
    "ko"    => "ko",
  }.freeze

  # nil -> default; recognized alias -> canonical; anything else -> nil.
  def self.normalize_lang(raw)
    return DEFAULT_LANG if raw.nil?
    return nil unless raw.is_a?(String)

    LANG_ALIASES[raw.strip.downcase]
  end

  # --- Vocabulary dictionaries (zh-TW source value => localized value) ----

  PLANETS_EN = {
    "太陽" => "Sun", "月亮" => "Moon", "水星" => "Mercury", "金星" => "Venus",
    "火星" => "Mars", "木星" => "Jupiter", "土星" => "Saturn",
    "天王星" => "Uranus", "海王星" => "Neptune", "冥王星" => "Pluto",
    "北交點" => "North Node", "南交點" => "South Node",
    "福點" => "Part of Fortune", "莉莉絲" => "Lilith",
    "北交點定位星" => "North Node Ruler", "南交點定位星" => "South Node Ruler",
    "上升星座定位星" => "Ascendant Ruler",
  }.freeze

  PLANETS_JA = {
    "太陽" => "太陽", "月亮" => "月", "水星" => "水星", "金星" => "金星",
    "火星" => "火星", "木星" => "木星", "土星" => "土星",
    "天王星" => "天王星", "海王星" => "海王星", "冥王星" => "冥王星",
    "北交點" => "ドラゴンヘッド", "南交點" => "ドラゴンテイル",
    "福點" => "パート・オブ・フォーチュン", "莉莉絲" => "リリス",
    "北交點定位星" => "ドラゴンヘッドの支配星",
    "南交點定位星" => "ドラゴンテイルの支配星",
    "上升星座定位星" => "アセンダントの支配星",
  }.freeze

  PLANETS_KO = {
    "太陽" => "태양", "月亮" => "달", "水星" => "수성", "金星" => "금성",
    "火星" => "화성", "木星" => "목성", "土星" => "토성",
    "天王星" => "천왕성", "海王星" => "해왕성", "冥王星" => "명왕성",
    "北交點" => "북교점", "南交點" => "남교점",
    "福點" => "포르투나", "莉莉絲" => "릴리트",
    "北交點定位星" => "북교점 지배성", "南交點定位星" => "남교점 지배성",
    "上升星座定位星" => "상승궁 지배성",
  }.freeze

  ZODIAC_ZH = [
    "牡羊座", "金牛座", "雙子座", "巨蟹座", "獅子座", "處女座",
    "天秤座", "天蠍座", "射手座", "摩羯座", "水瓶座", "雙魚座",
  ].freeze

  ZODIAC_EN = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
  ].freeze

  ZODIAC_JA = [
    "牡羊座", "牡牛座", "双子座", "蟹座", "獅子座", "乙女座",
    "天秤座", "蠍座", "射手座", "山羊座", "水瓶座", "魚座",
  ].freeze

  ZODIAC_KO = [
    "양자리", "황소자리", "쌍둥이자리", "게자리", "사자자리", "처녀자리",
    "천칭자리", "전갈자리", "궁수자리", "염소자리", "물병자리", "물고기자리",
  ].freeze

  ASPECTS_EN = {
    "合相" => "Conjunction", "六分相" => "Sextile", "四分相" => "Square",
    "三分相" => "Trine", "對分相" => "Opposition",
  }.freeze

  ASPECTS_JA = {
    "合相" => "コンジャンクション", "六分相" => "セクスタイル",
    "四分相" => "スクエア", "三分相" => "トライン", "對分相" => "オポジション",
  }.freeze

  ASPECTS_KO = {
    "合相" => "컨정션", "六分相" => "섹스타일", "四分相" => "스퀘어",
    "三分相" => "트라인", "對分相" => "어포지션",
  }.freeze

  PATTERNS_EN = {
    "大三角" => "Grand Trine", "T三角" => "T-Square", "大十字" => "Grand Cross",
  }.freeze

  PATTERNS_JA = {
    "大三角" => "グランドトライン", "T三角" => "Tスクエア", "大十字" => "グランドクロス",
  }.freeze

  PATTERNS_KO = {
    "大三角" => "그랜드 트라인", "T三角" => "T 스퀘어", "大十字" => "그랜드 크로스",
  }.freeze

  ELEMENTS_EN = { "火" => "Fire", "土" => "Earth", "風" => "Air", "水" => "Water" }.freeze
  ELEMENTS_JA = { "火" => "火", "土" => "地", "風" => "風", "水" => "水" }.freeze
  ELEMENTS_KO = { "火" => "불", "土" => "흙", "風" => "공기", "水" => "물" }.freeze

  MODALITIES_EN = { "基本" => "Cardinal", "固定" => "Fixed", "變動" => "Mutable" }.freeze
  MODALITIES_JA = { "基本" => "活動", "固定" => "不動", "變動" => "柔軟" }.freeze
  MODALITIES_KO = { "基本" => "활동궁", "固定" => "고정궁", "變動" => "변통궁" }.freeze

  # Flat zh-TW-value => localized-value dictionary per lang.
  LOCALES = {
    "en" => [
      PLANETS_EN, ZODIAC_ZH.zip(ZODIAC_EN).to_h, ASPECTS_EN,
      PATTERNS_EN, ELEMENTS_EN, MODALITIES_EN,
    ].reduce(:merge).freeze,
    "ja" => [
      PLANETS_JA, ZODIAC_ZH.zip(ZODIAC_JA).to_h, ASPECTS_JA,
      PATTERNS_JA, ELEMENTS_JA, MODALITIES_JA,
    ].reduce(:merge).freeze,
    "ko" => [
      PLANETS_KO, ZODIAC_ZH.zip(ZODIAC_KO).to_h, ASPECTS_KO,
      PATTERNS_KO, ELEMENTS_KO, MODALITIES_KO,
    ].reduce(:merge).freeze,
  }.freeze

  # --- Payload walking rules ---------------------------------------------

  # Hash keys whose STRING VALUE is a vocabulary term to translate.
  VALUE_KEYS = %w[
    planet a_planet b_planet transit_planet natal_planet progressed_planet
    planet_a planet_b apex ruling_planet zodiac aspect_type pattern_type
    element
  ].freeze

  # Hash keys whose value is a Hash whose KEYS are vocabulary terms
  # (values — house numbers / counts — stay untouched).
  KEY_TRANSLATED_HASHES = %w[
    a_planets_in_b_houses b_planets_in_a_houses elements modalities
  ].freeze

  # Subtrees never translated (input echo blocks).
  SKIP_KEYS = %w[input].freeze

  # Deep-translate a response data structure. zh-TW is the identity: the
  # exact same object is returned untouched.
  def self.translate_payload(obj, lang)
    return obj if lang.nil? || lang == DEFAULT_LANG

    walk(obj, LOCALES.fetch(lang))
  end

  def self.walk(obj, dict)
    case obj
    when Hash
      obj.each_with_object({}) do |(key, value), out|
        out[key] =
          if SKIP_KEYS.include?(key)
            value
          elsif VALUE_KEYS.include?(key)
            value.is_a?(String) ? dict.fetch(value, value) : value
          elsif KEY_TRANSLATED_HASHES.include?(key) && value.is_a?(Hash)
            value.transform_keys { |k| dict.fetch(k, k) }
          elsif key == "planets" && value.is_a?(Array) && value.all? { |e| e.is_a?(String) }
            # patterns[].planets — plain arrays of planet names
            value.map { |e| dict.fetch(e, e) }
          else
            walk(value, dict)
          end
      end
    when Array
      obj.map { |element| walk(element, dict) }
    else
      obj
    end
  end
  private_class_method :walk

  # --- Error message catalog ---------------------------------------------

  ERRORS = {
    "zh-TW" => {
      "invalid_json_object" => "請求主體必須為 JSON 物件",
      "invalid_json_format" => "無效的 JSON 格式",
      "missing_param"       => "缺少參數：%{name}",
      "orb_limit_numeric"   => "orb_limit 必須為數字",
      "year_integer"        => "year 必須為整數",
      "at_object"           => "at 必須為物件（含 date/time/timezone）",
      "invalid_timezone"    => "無效的時區識別碼：%{timezone}",
      "birth_dst"           => "此出生時間落在日光節約時間切換區間，無法對應唯一時刻，請確認實際時間",
      "moment_dst"          => "此時間落在日光節約時間切換區間，無法對應唯一時刻，請確認實際時間",
      "progression_dst"     => "推運目標日期在此時區的出生時刻不存在或不唯一，請改用其他日期",
      "date_out_of_range"   => "日期超出可計算範圍（1885–2099）",
      "polar_latitude"      => "極區緯度無法計算 Placidus 宮位",
      "invalid_date_or_time" => "無效的日期或時間",
      "invalid_house_system" => "無效的宮位制式：%{value}（支援 P / placidus 或 W / whole_sign）",
      "invalid_coordinates" => "無效的座標：緯度須在 ±90、經度須在 ±180 之間",
      "invalid_birth_date"  => "無效的出生日期，格式須為 YYYY-MM-DD",
      "invalid_birth_time"  => "無效的出生時間，格式須為 HH:MM",
      "internal_error"      => "伺服器內部錯誤，請稍後再試",
      "not_found"           => "找不到此 API 路徑",
      "invalid_lang"        => "不支援的語言：%{value}（支援 zh-TW / en / ja / ko）",
      "invalid_api_key"     => "API 金鑰無效或已撤銷",
      "key_required"        => "此端點需要 API 金鑰",
      "quota_exceeded"      => "已超過本月用量上限（%{limit} 次）",
      "monthly_limit_integer" => "monthly_limit 必須為非負整數或留空",
      "invalid_email"       => "電子郵件格式無效",
      "signup_rate_limited" => "今日申請次數過多，請明日再試",
      "admin_unauthorized"  => "管理權杖無效",
      "admin_disabled"      => "管理介面未啟用",
    }.freeze,
    "en" => {
      "invalid_json_object" => "Request body must be a JSON object",
      "invalid_json_format" => "Invalid JSON format",
      "missing_param"       => "Missing parameter: %{name}",
      "orb_limit_numeric"   => "orb_limit must be a number",
      "year_integer"        => "year must be an integer",
      "at_object"           => "at must be an object containing date/time/timezone",
      "invalid_timezone"    => "Invalid timezone identifier: %{timezone}",
      "birth_dst"           => "This birth time falls in a daylight-saving transition gap and does not map to a unique moment; please verify the actual time",
      "moment_dst"          => "This time falls in a daylight-saving transition gap and does not map to a unique moment; please verify the actual time",
      "progression_dst"     => "The birth time on the progressed target date does not exist or is not unique in this timezone; please use another date",
      "date_out_of_range"   => "Date is outside the computable range (1885–2099)",
      "polar_latitude"      => "Placidus houses cannot be computed at polar latitudes",
      "invalid_date_or_time" => "Invalid date or time",
      "invalid_house_system" => "Invalid house system: %{value} (supported: P / placidus or W / whole_sign)",
      "invalid_coordinates" => "Invalid coordinates: latitude must be within ±90 and longitude within ±180",
      "invalid_birth_date"  => "Invalid birth date; the format must be YYYY-MM-DD",
      "invalid_birth_time"  => "Invalid birth time; the format must be HH:MM",
      "internal_error"      => "Internal server error; please try again later",
      "not_found"           => "API path not found",
      "invalid_lang"        => "Unsupported language: %{value} (supported: zh-TW / en / ja / ko)",
      "invalid_api_key"     => "API key is invalid or has been revoked",
      "key_required"        => "This endpoint requires an API key",
      "quota_exceeded"      => "Monthly usage limit exceeded (%{limit} calls)",
      "monthly_limit_integer" => "monthly_limit must be a non-negative integer or omitted",
      "invalid_email"       => "Invalid email address format",
      "signup_rate_limited" => "Too many signups from this address today; please try again tomorrow",
      "admin_unauthorized"  => "Invalid admin token",
      "admin_disabled"      => "Admin interface is not enabled",
    }.freeze,
    "ja" => {
      "invalid_json_object" => "リクエストボディは JSON オブジェクトである必要があります",
      "invalid_json_format" => "無効な JSON 形式です",
      "missing_param"       => "パラメータが不足しています：%{name}",
      "orb_limit_numeric"   => "orb_limit は数値である必要があります",
      "year_integer"        => "year は整数である必要があります",
      "at_object"           => "at はオブジェクト（date/time/timezone を含む）である必要があります",
      "invalid_timezone"    => "無効なタイムゾーン識別子：%{timezone}",
      "birth_dst"           => "この出生時刻はサマータイム切替の区間にあり、一意の時刻に対応できません。実際の時刻をご確認ください",
      "moment_dst"          => "この時刻はサマータイム切替の区間にあり、一意の時刻に対応できません。実際の時刻をご確認ください",
      "progression_dst"     => "進行の対象日ではこのタイムゾーンに出生時刻が存在しないか一意ではありません。別の日付をご利用ください",
      "date_out_of_range"   => "日付が計算可能な範囲（1885–2099）を超えています",
      "polar_latitude"      => "極地の緯度では Placidus ハウスを計算できません",
      "invalid_date_or_time" => "無効な日付または時刻です",
      "invalid_house_system" => "無効なハウスシステム：%{value}（P / placidus または W / whole_sign に対応）",
      "invalid_coordinates" => "無効な座標：緯度は ±90、経度は ±180 の範囲内である必要があります",
      "invalid_birth_date"  => "無効な出生日です。形式は YYYY-MM-DD である必要があります",
      "invalid_birth_time"  => "無効な出生時刻です。形式は HH:MM である必要があります",
      "internal_error"      => "サーバー内部エラーです。しばらくしてから再度お試しください",
      "not_found"           => "この API パスが見つかりません",
      "invalid_lang"        => "未対応の言語です：%{value}（zh-TW / en / ja / ko に対応）",
      "invalid_api_key"     => "API キーが無効か、失効しています",
      "key_required"        => "このエンドポイントには API キーが必要です",
      "quota_exceeded"      => "今月の利用上限（%{limit} 回）を超えました",
      "monthly_limit_integer" => "monthly_limit は 0 以上の整数か未指定である必要があります",
      "invalid_email"       => "メールアドレスの形式が無効です",
      "signup_rate_limited" => "本日のこのアドレスからの申請が多すぎます。明日再度お試しください",
      "admin_unauthorized"  => "管理トークンが無効です",
      "admin_disabled"      => "管理インターフェースは有効化されていません",
    }.freeze,
    "ko" => {
      "invalid_json_object" => "요청 본문은 JSON 객체여야 합니다",
      "invalid_json_format" => "잘못된 JSON 형식입니다",
      "missing_param"       => "누락된 매개변수: %{name}",
      "orb_limit_numeric"   => "orb_limit 은(는) 숫자여야 합니다",
      "year_integer"        => "year 은(는) 정수여야 합니다",
      "at_object"           => "at 은(는) date/time/timezone 을 포함한 객체여야 합니다",
      "invalid_timezone"    => "잘못된 시간대 식별자: %{timezone}",
      "birth_dst"           => "이 출생 시각은 일광 절약 시간 전환 구간에 있어 고유한 시각에 대응할 수 없습니다. 실제 시각을 확인해 주세요",
      "moment_dst"          => "이 시각은 일광 절약 시간 전환 구간에 있어 고유한 시각에 대응할 수 없습니다. 실제 시각을 확인해 주세요",
      "progression_dst"     => "진행 대상 날짜의 출생 시각이 이 시간대에 존재하지 않거나 고유하지 않습니다. 다른 날짜를 사용해 주세요",
      "date_out_of_range"   => "날짜가 계산 가능한 범위(1885–2099)를 벗어났습니다",
      "polar_latitude"      => "극지방 위도에서는 Placidus 하우스를 계산할 수 없습니다",
      "invalid_date_or_time" => "잘못된 날짜 또는 시각입니다",
      "invalid_house_system" => "잘못된 하우스 시스템: %{value} (P / placidus 또는 W / whole_sign 지원)",
      "invalid_coordinates" => "잘못된 좌표: 위도는 ±90, 경도는 ±180 범위여야 합니다",
      "invalid_birth_date"  => "잘못된 출생 날짜입니다. 형식은 YYYY-MM-DD 여야 합니다",
      "invalid_birth_time"  => "잘못된 출생 시각입니다. 형식은 HH:MM 이어야 합니다",
      "internal_error"      => "서버 내부 오류입니다. 잠시 후 다시 시도해 주세요",
      "not_found"           => "해당 API 경로를 찾을 수 없습니다",
      "invalid_lang"        => "지원하지 않는 언어: %{value} (지원: zh-TW / en / ja / ko)",
      "invalid_api_key"     => "API 키가 유효하지 않거나 취소되었습니다",
      "key_required"        => "이 엔드포인트에는 API 키가 필요합니다",
      "quota_exceeded"      => "이번 달 사용 한도(%{limit}회)를 초과했습니다",
      "monthly_limit_integer" => "monthly_limit 은(는) 0 이상의 정수이거나 생략해야 합니다",
      "invalid_email"       => "이메일 주소 형식이 올바르지 않습니다",
      "signup_rate_limited" => "오늘 이 주소에서 너무 많이 신청했습니다. 내일 다시 시도해 주세요",
      "admin_unauthorized"  => "관리 토큰이 유효하지 않습니다",
      "admin_disabled"      => "관리 인터페이스가 활성화되지 않았습니다",
    }.freeze,
  }.freeze

  # Resolve an error message by catalog key. Unknown key in the requested
  # locale falls back to the zh-TW template; unknown everywhere falls back
  # to the given zh fallback string (or the key itself).
  def self.error_message(key, lang, fallback = nil, args = {})
    lang = DEFAULT_LANG unless SUPPORTED_LANGS.include?(lang)
    template = ERRORS.fetch(lang)[key.to_s] || ERRORS.fetch(DEFAULT_LANG)[key.to_s]
    return fallback || key.to_s if template.nil?

    format(template, **args.transform_keys(&:to_sym))
  end

  # --- Cities ------------------------------------------------------------

  # zh city name => primary English name (first alt alias).
  CITY_EN_NAMES = Cities::CITIES.to_h { |c| [c["name"], c["alt"].first] }.freeze

  # zh country name => English country name (used for en / ja / ko alike;
  # ja / ko country names are deliberately not attempted).
  COUNTRY_EN = {
    "台灣" => "Taiwan", "日本" => "Japan", "韓國" => "South Korea",
    "中國" => "China", "香港" => "Hong Kong", "澳門" => "Macau",
    "新加坡" => "Singapore", "馬來西亞" => "Malaysia", "泰國" => "Thailand",
    "越南" => "Vietnam", "菲律賓" => "Philippines", "印尼" => "Indonesia",
    "柬埔寨" => "Cambodia", "緬甸" => "Myanmar", "印度" => "India",
    "巴基斯坦" => "Pakistan", "孟加拉" => "Bangladesh", "斯里蘭卡" => "Sri Lanka",
    "尼泊爾" => "Nepal", "阿拉伯聯合大公國" => "United Arab Emirates",
    "沙烏地阿拉伯" => "Saudi Arabia", "卡達" => "Qatar", "以色列" => "Israel",
    "伊朗" => "Iran", "伊拉克" => "Iraq", "蒙古" => "Mongolia",
    "哈薩克" => "Kazakhstan", "英國" => "United Kingdom", "愛爾蘭" => "Ireland",
    "法國" => "France", "德國" => "Germany", "荷蘭" => "Netherlands",
    "比利時" => "Belgium", "盧森堡" => "Luxembourg", "瑞士" => "Switzerland",
    "奧地利" => "Austria", "捷克" => "Czechia", "波蘭" => "Poland",
    "匈牙利" => "Hungary", "義大利" => "Italy", "西班牙" => "Spain",
    "葡萄牙" => "Portugal", "希臘" => "Greece", "土耳其" => "Turkey",
    "丹麥" => "Denmark", "瑞典" => "Sweden", "挪威" => "Norway",
    "芬蘭" => "Finland", "冰島" => "Iceland", "俄羅斯" => "Russia",
    "烏克蘭" => "Ukraine", "羅馬尼亞" => "Romania", "美國" => "United States",
    "加拿大" => "Canada", "墨西哥" => "Mexico", "古巴" => "Cuba",
    "巴拿馬" => "Panama", "瓜地馬拉" => "Guatemala",
    "哥斯大黎加" => "Costa Rica", "巴西" => "Brazil", "阿根廷" => "Argentina",
    "智利" => "Chile", "秘魯" => "Peru", "哥倫比亞" => "Colombia",
    "厄瓜多" => "Ecuador", "委內瑞拉" => "Venezuela", "烏拉圭" => "Uruguay",
    "玻利維亞" => "Bolivia", "埃及" => "Egypt", "奈及利亞" => "Nigeria",
    "肯亞" => "Kenya", "南非" => "South Africa", "摩洛哥" => "Morocco",
    "阿爾及利亞" => "Algeria", "突尼西亞" => "Tunisia", "迦納" => "Ghana",
    "衣索比亞" => "Ethiopia", "坦尚尼亞" => "Tanzania",
    "剛果民主共和國" => "DR Congo", "澳洲" => "Australia",
    "紐西蘭" => "New Zealand", "斐濟" => "Fiji",
  }.freeze

  # Localize /api/v1/cities rows. zh-TW keeps 中文 name + country untouched;
  # en / ja / ko use the primary English city name and the English country
  # name. Matching behavior is unaffected (this runs on results only).
  def self.localize_cities(results, lang)
    return results if lang.nil? || lang == DEFAULT_LANG

    results.map do |city|
      city.merge(
        "name"    => CITY_EN_NAMES.fetch(city["name"], city["name"]),
        "country" => COUNTRY_EN.fetch(city["country"], city["country"])
      )
    end
  end
end
