require "sinatra/base"
require "json"
require "date"
require "tzinfo"
require "astro_chart"
require "rack/utils"
require_relative "lib/cities"
require_relative "lib/i18n"
require_relative "lib/store"
require_relative "lib/disposable_domains"
require_relative "lib/mailer"

class AstroWeb < Sinatra::Base
  set :public_folder, File.expand_path("public", __dir__)
  set :views, File.expand_path("views", __dir__)
  set :show_exceptions, false
  set :raise_errors, false
  set :store, Store.new

  # Endpoints that require authentication (open mode: key optional) and
  # count toward usage. /health and /usage are handled separately.
  # (Sinatra/Mustermann full-matches, so no \A..\z anchors here.)
  BILLABLE = %r{/api/v1/(?:charts|synastry|transits|progressions|composite|solar-return|cities)}

  # Deliberately lenient, single-line: one @ with non-space/@ on each side
  # and a dotted domain. Good enough to reject typos without rejecting valid
  # real-world addresses.
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  # RFC 5321 caps a forward-path address at 254 characters.
  EMAIL_MAX_LENGTH = 254
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
    attr_reader :code, :message_key, :args, :status

    # status is positional (not a keyword) so existing call sites that pass
    # args as trailing key: value pairs keep packing into `args`.
    def initialize(code, message_key, args = {}, status = 400)
      @code = code
      @message_key = message_key.to_s
      @args = args
      @status = status
      super(I18n.error_message(@message_key, I18n::DEFAULT_LANG, nil, args))
    end
  end

  before %r{/api(?:/.*)?} do
    headers "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Headers" => "Content-Type, Authorization, X-API-Key"
  end

  options "/api/v1/*" do
    headers "Access-Control-Allow-Methods" => "POST,GET,OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type, Authorization, X-API-Key"
    204
  end

  # Authenticate billable endpoints (open mode allows anonymous), then count
  # each successful call. The resolved key is carried in @api_key.
  before BILLABLE do
    authenticate!
  end

  after BILLABLE do
    record_usage_for_request if response.status == 200
  end

  # Admin API is protected by ADMIN_TOKEN. The /admin page itself (exact path,
  # no trailing segment) is public — it prompts for the token client-side.
  before %r{/admin/.+} do
    admin_authenticate!
  end

  get "/api/v1/health" do
    json_body("status" => "ok", "gem_version" => AstroChart::VERSION)
  end

  # A caller inspects their own usage. Requires a key even in open mode
  # (anonymous usage is not attributable). Not counted, not translated.
  get "/api/v1/usage" do
    set_lang!(params["lang"])
    token = extract_api_token
    raise ApiError.new("key_required", :key_required, {}, 401) if token.nil?

    key = settings.store.find_key_by_token(token)
    raise ApiError.new("invalid_api_key", :invalid_api_key, {}, 401) if key.nil?

    json_body("data" => settings.store.usage_summary(key, current_month))
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

  # Self-serve API-key signup — double opt-in. Public, JSON, not billable.
  # Step 1: stage a pending signup and email a confirmation link. NO key is
  # issued here. Abuse-throttled per-IP per-day; disposable domains rejected.
  post "/api/v1/signup" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    email = payload["email"].to_s.strip
    unless email.length <= EMAIL_MAX_LENGTH && email.match?(EMAIL_FORMAT)
      raise ApiError.new("invalid_email", :invalid_email)
    end
    raise ApiError.new("disposable_email", :disposable_email) if DisposableDomains.disposable?(email)

    ip = client_ip
    if settings.store.pending_signups_from_ip_today(ip) >= signup_daily_ip_limit
      raise ApiError.new("signup_rate_limited", :signup_rate_limited, {}, 429)
    end

    pending = settings.store.create_pending_signup(email: email, ip: ip)
    link = "#{request.base_url}/verify?token=#{pending['token']}"
    Mailer.send_verification(email: email, link: link, lang: current_lang)

    status 202
    json_body("data" => { "status" => "verification_sent", "email" => email })
  end

  # Step 2 (from the email link): confirm ownership and issue the key. Uses a
  # deliberate POST (the GET /verify page click) so email link-scanners that
  # only fetch GET can't consume the one-time token.
  post "/api/v1/verify" do
    payload = parse_json_body
    set_lang!(payload["lang"])
    result = settings.store.consume_pending_signup(payload["token"])
    case result["status"]
    when "expired" then raise ApiError.new("verification_expired", :verification_expired)
    when "ok"      then nil
    else raise ApiError.new("verification_invalid", :verification_invalid)
    end

    key = settings.store.create_signup_key(
      email: result["email"], ip: result["ip"], monthly_limit: signup_monthly_limit
    )
    status 201
    json_body("data" => {
      "token" => key["token"], "prefix" => key["prefix"],
      "monthly_limit" => key["monthly_limit"], "tier" => key["tier"]
    })
  end

  get "/openapi.json" do
    path = File.join(settings.public_folder, "openapi.json")
    halt 404 unless File.file?(path)

    send_file path, type: :json
  end

  # ---- Admin (protected by ADMIN_TOKEN) ----

  post "/admin/api-keys" do
    payload = parse_json_body
    limit = payload["monthly_limit"]
    unless limit.nil? || (limit.is_a?(Integer) && limit >= 0)
      raise ApiError.new("missing_param", :monthly_limit_integer)
    end

    key = settings.store.create_key(
      label: payload["label"].to_s,
      tier: (payload["tier"] || "free").to_s,
      monthly_limit: limit
    )
    status 201
    json_body("data" => key)
  end

  get "/admin/api-keys" do
    json_body("data" => settings.store.list_keys)
  end

  delete "/admin/api-keys/:id" do
    # Raise (not halt) so the JSON ApiError handler renders it — a bare halt 404
    # on this non-/api path would fall through to the site-wide HTML 404.
    revoked = settings.store.revoke_key(params["id"])
    raise ApiError.new("not_found", :not_found, {}, 404) unless revoked

    json_body("data" => { "id" => params["id"].to_i, "revoked" => true })
  end

  get "/admin/usage" do
    month = params["month"] || current_month
    json_body("data" => settings.store.global_usage(month))
  end

  get "/admin" do
    erb :admin
  end

  get "/" do
    erb :index
  end

  get "/docs" do
    params["lang"] == "en" ? erb(:docs_en) : erb(:docs)
  end

  # Public self-serve signup page (standalone HTML, no layout).
  get "/signup" do
    erb :signup, layout: false
  end

  # Landing for the emailed verification link; the page POSTs the token to
  # /api/v1/verify on a click and shows the issued key once.
  get "/verify" do
    erb :verify, layout: false
  end

  # SEO helpers. Public, unauthenticated, not billable (non-/api paths).
  get "/robots.txt" do
    content_type "text/plain"
    "User-agent: *\nAllow: /\nSitemap: https://astro-chart-api.fly.dev/sitemap.xml\n"
  end

  get "/sitemap.xml" do
    content_type "application/xml"
    base = "https://astro-chart-api.fly.dev"
    paths = ["/", "/docs", "/docs?lang=en", "/signup"]
    urls = paths.map do |p|
      "  <url><loc>#{Rack::Utils.escape_html(base + p)}</loc></url>"
    end.join("\n")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{urls}
      </urlset>
    XML
  end

  error ApiError do
    api_error = env["sinatra.error"]
    message = I18n.error_message(api_error.message_key, current_lang,
                                 api_error.message, api_error.args)
    json_error(api_error.status, api_error.code, message)
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

  # ---- Authentication & usage ----

  # Resolve the caller's API key for a billable request. In open mode a
  # missing key means anonymous (@api_key stays nil); in required mode it is
  # a 401. A present-but-unknown key is always a 401. Enforces monthly quota.
  def authenticate!
    token = extract_api_token
    if token.nil?
      raise ApiError.new("key_required", :key_required, {}, 401) if key_mode == "required"

      @api_key = nil
      return
    end

    key = settings.store.find_key_by_token(token)
    raise ApiError.new("invalid_api_key", :invalid_api_key, {}, 401) if key.nil?

    enforce_quota!(key)
    @api_key = key
  end

  def enforce_quota!(key)
    limit = key["monthly_limit"]
    return if limit.nil?

    used = settings.store.month_count(key["id"], current_month)
    return if used < limit.to_i

    raise ApiError.new("quota_exceeded", :quota_exceeded, { limit: limit }, 429)
  end

  # Count a successful billable call against the resolved key (or anonymous).
  # Metering must never break a good response.
  def record_usage_for_request
    key_id = @api_key ? @api_key["id"] : Store::ANONYMOUS_KEY_ID
    endpoint = request.path_info.sub(%r{\A/api/v1/}, "")
    settings.store.record_usage(key_id, endpoint, Time.now.utc.strftime("%Y-%m-%d"))
  rescue StandardError
    nil
  end

  def extract_api_token
    bearer = extract_bearer
    return bearer if bearer

    header = request.env["HTTP_X_API_KEY"]
    return header.strip if header && !header.strip.empty?

    query = params["api_key"]
    return query.strip if query && !query.strip.empty?

    nil
  end

  def extract_bearer
    auth = request.env["HTTP_AUTHORIZATION"]
    return nil unless auth

    match = auth.match(/\ABearer\s+(.+)\z/i)
    match && match[1].strip
  end

  def key_mode
    (ENV["API_KEY_MODE"] || "open").downcase
  end

  # Client IP for signup throttling. Behind Fly.io the trusted proxy exposes
  # the real client IP via Fly-Client-IP and APPENDS it to the end of
  # X-Forwarded-For; the FIRST XFF entry is whatever the untrusted client sent
  # (spoofable). Prefer Fly-Client-IP, then the LAST XFF hop, then request.ip.
  def client_ip
    fly = request.env["HTTP_FLY_CLIENT_IP"].to_s.strip
    return fly unless fly.empty?

    fwd = request.env["HTTP_X_FORWARDED_FOR"].to_s
    last = fwd.split(",").map(&:strip).reject(&:empty?).last.to_s
    last.empty? ? request.ip.to_s : last
  end

  # Per-IP daily signup cap (default 5).
  def signup_daily_ip_limit
    (ENV["SIGNUP_DAILY_IP_LIMIT"] || "5").to_i
  end

  # Default monthly quota for self-serve keys. Unset => nil (unlimited),
  # matching the open-beta stance.
  def signup_monthly_limit
    raw = ENV["SIGNUP_MONTHLY_LIMIT"]
    raw.nil? || raw.strip.empty? ? nil : raw.to_i
  end

  def current_month
    Time.now.utc.strftime("%Y-%m")
  end

  # Guard the admin API. Disabled (503) unless ADMIN_TOKEN is set; otherwise a
  # constant-time comparison against the Bearer token.
  def admin_authenticate!
    expected = ENV["ADMIN_TOKEN"].to_s
    raise ApiError.new("admin_disabled", :admin_disabled, {}, 503) if expected.empty?

    provided = extract_bearer.to_s
    unless provided.length == expected.length && Rack::Utils.secure_compare(provided, expected)
      raise ApiError.new("admin_unauthorized", :admin_unauthorized, {}, 401)
    end
  end

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
