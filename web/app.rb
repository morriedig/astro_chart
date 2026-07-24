require "sinatra/base"
require "json"
require "date"
require "tzinfo"
require "astro_chart"
require_relative "lib/cities"
require_relative "lib/i18n"

class AstroWeb < Sinatra::Base
  set :public_folder, File.expand_path("public", __dir__)
  set :views, File.expand_path("views", __dir__)
  set :show_exceptions, false
  set :raise_errors, false

  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  TIME_FORMAT = /\A(\d{1,2}):(\d{2})\z/
  CHART_PARAMS = %w[birth_date birth_time latitude longitude timezone].freeze
  HOUSE_SYSTEM_ALIASES = {
    "p" => "P", "placidus" => "P",
    "w" => "W", "whole_sign" => "W",
  }.freeze

  # code: machine-readable error code returned to the client.
  # message_key: I18n::ERRORS catalog key; args interpolate %{...} slots.
  # #message stays the zh-TW rendering (log/back-compat); the error
  # handler re-renders per request lang.
  class ApiError < StandardError
    attr_reader :code, :message_key, :args

    def initialize(code, message_key, args = {})
      @code = code
      @message_key = message_key.to_s
      @args = args
      super(I18n.error_message(@message_key, I18n::DEFAULT_LANG, nil, args))
    end
  end

  before %r{/api(?:/.*)?} do
    headers "Access-Control-Allow-Origin" => "*"
  end

  options "/api/v1/*" do
    headers "Access-Control-Allow-Methods" => "POST,GET,OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type"
    204
  end

  get "/api/v1/health" do
    json_body("status" => "ok", "gem_version" => AstroChart::VERSION)
  end

  post "/api/v1/charts" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    json_data(build_chart(payload))
  end

  post "/api/v1/synastry" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    a_chart = build_chart(chart_params(payload, "a"))
    b_chart = build_chart(chart_params(payload, "b"))
    orb_limit = orb_limit_from(payload)
    synastry = AstroChart::Synastry.between(a_chart, b_chart, orb_limit: orb_limit)
    json_data(
      "a_chart" => a_chart,
      "b_chart" => b_chart,
      "synastry" => synastry,
    )
  end

  post "/api/v1/transits" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    natal_chart = build_chart(chart_params(payload, "natal"))
    orb_limit = orb_limit_from(payload) || 3.0
    jd, transit_time_utc = transit_moment(payload["at"])
    result = astro_call do
      AstroChart::Transits.against(natal_chart, jd, orb_limit: orb_limit)
    end
    json_data(
      "natal_chart"      => natal_chart,
      "transit_time_utc" => transit_time_utc,
      "planets"          => result["planets"],
      "aspects"          => result["aspects"],
    )
  end

  post "/api/v1/progressions" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    natal_chart = build_chart(chart_params(payload, "natal"))
    target_date = payload["target_date"]
    raise ApiError.new("missing_param", :missing_param, name: "target_date") if target_date.nil?

    validate_date!(target_date)
    orb_limit = orb_limit_from(payload) || 1.0
    progression = astro_call do
      AstroChart::Progressions.secondary(natal_chart, target_date, orb_limit: orb_limit)
    rescue TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
      raise ApiError.new("invalid_time", :progression_dst)
    end
    json_data(
      "natal_chart" => natal_chart,
      "progression" => progression,
    )
  end

  post "/api/v1/composite" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    a_chart = build_chart(chart_params(payload, "a"))
    b_chart = build_chart(chart_params(payload, "b"))
    json_data(
      "a_chart"   => a_chart,
      "b_chart"   => b_chart,
      "composite" => AstroChart::Composite.between(a_chart, b_chart),
    )
  end

  post "/api/v1/solar-return" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    natal_chart = build_chart(chart_params(payload, "natal"))
    year = payload["year"]
    raise ApiError.new("missing_param", :missing_param, name: "year") if year.nil?
    raise ApiError.new("missing_param", :year_integer) unless year.is_a?(Integer)

    latitude, longitude = solar_return_coordinates(payload)
    timezone = payload["timezone"]
    validate_timezone!(timezone) unless timezone.nil?

    solar_return = astro_call do
      AstroChart::SolarReturn.for_year(
        natal_chart, year,
        latitude: latitude, longitude: longitude, timezone: timezone
      )
    end
    json_data(
      "natal_chart"  => natal_chart,
      "solar_return" => solar_return,
    )
  end

  get "/api/v1/cities" do
    set_lang!(params["lang"])
    q = params["q"]
    raise ApiError.new("missing_param", :missing_param, name: "q") if q.nil? || q.strip.empty?

    json_body("data" => I18n.localize_cities(Cities.search(q.strip), current_lang))
  end

  get "/openapi.json" do
    path = File.join(settings.public_folder, "openapi.json")
    halt 404 unless File.file?(path)

    send_file path, type: :json
  end

  get "/" do
    erb :index
  end

  get "/docs" do
    params["lang"] == "en" ? erb(:docs_en) : erb(:docs)
  end

  error ApiError do
    api_error = env["sinatra.error"]
    message = I18n.error_message(api_error.message_key, current_lang,
                                 api_error.message, api_error.args)
    json_error(400, api_error.code, message)
  end

  error do
    json_error(500, "internal_error", I18n.error_message(:internal_error, current_lang))
  end

  not_found do
    if request.path_info.start_with?("/api")
      json_error(404, "not_found", I18n.error_message(:not_found, current_lang))
    else
      content_type :html
      "<h1>404</h1><p>找不到頁面</p>"
    end
  end

  private

  # Request language, resolved by set_lang!. Defaults to zh-TW — also for
  # errors raised before lang can be read (e.g. malformed JSON).
  def current_lang
    @lang || I18n::DEFAULT_LANG
  end

  # Validate + store the request language. nil keeps the zh-TW default;
  # unrecognized values are a 400 invalid_lang.
  def set_lang!(raw)
    lang = I18n.normalize_lang(raw)
    raise ApiError.new("invalid_lang", :invalid_lang, value: raw) if lang.nil?

    @lang = lang
  end

  # Render {"data" => ...} with vocabulary values localized to the
  # request language (zh-TW passes through untouched).
  def json_data(data)
    json_body("data" => I18n.translate_payload(data, current_lang))
  end

  def parse_json_body
    payload = JSON.parse(raw_body)
    raise ApiError.new("invalid_json", :invalid_json_object) unless payload.is_a?(Hash)

    payload
  rescue JSON::ParserError
    raise ApiError.new("invalid_json", :invalid_json_format)
  end

  def raw_body
    body = request.body
    body.rewind if body.respond_to?(:rewind)
    content = body.read
    content = request.env["rack.request.form_vars"].to_s if content.empty?
    content
  end

  def chart_params(payload, key)
    params = payload[key]
    raise ApiError.new("missing_param", :missing_param, name: key) unless params.is_a?(Hash)

    params
  end

  def orb_limit_from(payload)
    orb_limit = payload["orb_limit"]
    return orb_limit if orb_limit.nil? || orb_limit.is_a?(Numeric)

    raise ApiError.new("missing_param", :orb_limit_numeric)
  end

  def build_chart(params)
    validate_chart_params!(params)
    house_system = house_system_from(params)
    AstroChart::Chart.new(
      birth_date: params["birth_date"],
      birth_time: params["birth_time"],
      latitude: params["latitude"].to_f,
      longitude: params["longitude"].to_f,
      timezone: params["timezone"],
      house_system: house_system
    ).generate
  rescue TZInfo::InvalidTimezoneIdentifier
    raise ApiError.new("invalid_timezone", :invalid_timezone, timezone: params["timezone"])
  rescue TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
    raise ApiError.new("invalid_time", :birth_dst)
  rescue AstroChart::Pure::Core::DomainError => e
    raise ApiError.new("date_out_of_range", :date_out_of_range) if e.message.include?("Pluto")

    raise ApiError.new("polar_latitude", :polar_latitude)
  rescue ArgumentError, TypeError
    raise ApiError.new("invalid_date", :invalid_date_or_time)
  end

  def house_system_from(params)
    raw = params["house_system"]
    return "P" if raw.nil?

    normalized = raw.is_a?(String) && HOUSE_SYSTEM_ALIASES[raw.strip.downcase]
    unless normalized
      raise ApiError.new("invalid_house_system", :invalid_house_system, value: raw)
    end

    normalized
  end

  # Map an optional "at" moment ({"date","time","timezone"}) — or nil for
  # the current UTC instant — to [julian_day, iso8601_utc_string].
  def transit_moment(at)
    return current_utc_moment if at.nil?

    raise ApiError.new("missing_param", :at_object) unless at.is_a?(Hash)

    %w[date time timezone].each do |key|
      raise ApiError.new("missing_param", :missing_param, name: "at.#{key}") if at[key].nil?
    end
    validate_date!(at["date"])
    validate_time!(at["time"])
    validate_timezone!(at["timezone"])

    tz = TZInfo::Timezone.get(at["timezone"])
    year, month, day = at["date"].split("-").map(&:to_i)
    hour, minute = at["time"].split(":").map(&:to_i)
    utc = tz.local_to_utc(Time.new(year, month, day, hour, minute, 0))
    jd = AstroChart::TimeConversion.to_julian_day(at["date"], at["time"], at["timezone"])
    [jd, utc.strftime("%Y-%m-%dT%H:%M:%SZ")]
  rescue TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
    raise ApiError.new("invalid_time", :moment_dst)
  end

  def current_utc_moment
    now = Time.now.utc
    ut_hour = now.hour + now.min / 60.0 + now.sec / 3600.0
    jd = AstroChart::Ephemeris.julday(now.year, now.month, now.day, ut_hour)
    [jd, now.strftime("%Y-%m-%dT%H:%M:%SZ")]
  end

  def solar_return_coordinates(payload)
    latitude = payload["latitude"]
    longitude = payload["longitude"]
    return [nil, nil] if latitude.nil? && longitude.nil?

    valid = (latitude.nil? || (latitude.is_a?(Numeric) && latitude.between?(-90, 90))) &&
            (longitude.nil? || (longitude.is_a?(Numeric) && longitude.between?(-180, 180)))
    raise ApiError.new("invalid_coordinates", :invalid_coordinates) unless valid

    [latitude, longitude]
  end

  # Shared rescue for ephemeris calls outside build_chart: turn the pure
  # backend's DomainError into the existing API error codes.
  def astro_call
    yield
  rescue AstroChart::Pure::Core::DomainError => e
    raise ApiError.new("date_out_of_range", :date_out_of_range) if e.message.include?("Pluto")

    raise ApiError.new("polar_latitude", :polar_latitude)
  end

  def validate_chart_params!(params)
    CHART_PARAMS.each do |key|
      raise ApiError.new("missing_param", :missing_param, name: key) if params[key].nil?
    end
    validate_date!(params["birth_date"])
    validate_time!(params["birth_time"])
    validate_coordinates!(params["latitude"], params["longitude"])
    validate_timezone!(params["timezone"])
  end

  def validate_date!(date)
    valid = date.is_a?(String) && date.match?(DATE_FORMAT) &&
            Date.valid_date?(*date.split("-").map(&:to_i))
    raise ApiError.new("invalid_date", :invalid_birth_date) unless valid
  end

  def validate_time!(time)
    match = time.is_a?(String) && time.match(TIME_FORMAT)
    valid = match && match[1].to_i.between?(0, 23) && match[2].to_i.between?(0, 59)
    raise ApiError.new("invalid_time", :invalid_birth_time) unless valid
  end

  def validate_coordinates!(latitude, longitude)
    valid = latitude.is_a?(Numeric) && latitude.between?(-90, 90) &&
            longitude.is_a?(Numeric) && longitude.between?(-180, 180)
    raise ApiError.new("invalid_coordinates", :invalid_coordinates) unless valid
  end

  def validate_timezone!(timezone)
    raise ApiError.new("invalid_timezone", :invalid_timezone, timezone: timezone) unless timezone.is_a?(String)

    TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    raise ApiError.new("invalid_timezone", :invalid_timezone, timezone: timezone)
  end

  def json_body(hash)
    content_type :json
    JSON.generate(hash)
  end

  def json_error(status_code, code, message)
    status status_code
    json_body("error" => { "code" => code, "message" => message })
  end
end
