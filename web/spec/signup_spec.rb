require_relative "spec_helper"
require "sqlite3"
require "tmpdir"
require "fileutils"
require "uri"

RSpec.describe "AstroWeb self-serve signup (double opt-in)" do
  def app
    AstroWeb
  end

  TAIPEI = {
    "birth_date" => "1990-01-01", "birth_time" => "12:00",
    "latitude" => 25.033, "longitude" => 121.5654, "timezone" => "Asia/Taipei"
  }.freeze

  def post_json(path, payload, headers = {})
    post path, JSON.generate(payload), { "CONTENT_TYPE" => "application/json" }.merge(headers)
  end

  def parsed
    JSON.parse(last_response.body)
  end

  # Spy on the mailer (no real send in tests — it would be :logged anyway),
  # capture the verification link, and pull the one-time token out of it.
  def signup_and_capture_token(email, headers = {})
    captured = nil
    allow(Mailer).to receive(:send_verification) do |**kw|
      captured = kw[:link]
      :logged
    end
    post_json "/api/v1/signup", { "email" => email }, headers
    return nil if captured.nil?

    URI.decode_www_form(URI(captured).query).to_h["token"]
  end

  around(:each) do |example|
    prev_limit = ENV["SIGNUP_DAILY_IP_LIMIT"]
    prev_monthly = ENV["SIGNUP_MONTHLY_LIMIT"]
    prev_mode = ENV["API_KEY_MODE"]
    example.run
    ENV["SIGNUP_DAILY_IP_LIMIT"] = prev_limit
    ENV["SIGNUP_MONTHLY_LIMIT"] = prev_monthly
    ENV["API_KEY_MODE"] = prev_mode
  end

  describe "POST /api/v1/signup (step 1: send verification)" do
    it "stages a pending signup, emails a link, and issues NO key yet" do
      expect(Mailer).to receive(:send_verification).with(
        hash_including(email: "dev@example.com")
      ).and_return(:logged)

      post_json "/api/v1/signup", { "email" => "dev@example.com" }
      expect(last_response.status).to eq(202)
      data = parsed.fetch("data")
      expect(data.fetch("status")).to eq("verification_sent")
      expect(data.fetch("email")).to eq("dev@example.com")
      expect(data).not_to have_key("token")
    end

    it "rejects a malformed email with 400 invalid_email (no email sent)" do
      expect(Mailer).not_to receive(:send_verification)
      post_json "/api/v1/signup", { "email" => "not-an-email" }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("invalid_email")
    end

    it "localizes invalid_email via lang" do
      post_json "/api/v1/signup", { "email" => "bad", "lang" => "en" }
      expect(parsed.dig("error", "message")).to eq("Invalid email address format")
    end

    it "rejects a disposable email domain with 400 disposable_email" do
      expect(Mailer).not_to receive(:send_verification)
      post_json "/api/v1/signup", { "email" => "throwaway@mailinator.com" }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("disposable_email")
    end

    it "rejects an oversized email with 400 invalid_email" do
      long = ("a" * 250) + "@" + ("b" * 250) + ".com"
      post_json "/api/v1/signup", { "email" => long }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("invalid_email")
    end

    it "throttles by IP once SIGNUP_DAILY_IP_LIMIT is reached (429)" do
      ENV["SIGNUP_DAILY_IP_LIMIT"] = "2"
      allow(Mailer).to receive(:send_verification).and_return(:logged)
      ip = "203.0.113.7"
      2.times do |i|
        post_json "/api/v1/signup", { "email" => "user#{i}@example.com" }, "HTTP_X_FORWARDED_FOR" => ip
        expect(last_response.status).to eq(202)
      end
      post_json "/api/v1/signup", { "email" => "user3@example.com" }, "HTTP_X_FORWARDED_FOR" => ip
      expect(last_response.status).to eq(429)
      expect(parsed.dig("error", "code")).to eq("signup_rate_limited")
    end

    it "keys the throttle on the trusted last X-Forwarded-For hop, not the spoofable first" do
      ENV["SIGNUP_DAILY_IP_LIMIT"] = "1"
      allow(Mailer).to receive(:send_verification).and_return(:logged)
      post_json "/api/v1/signup", { "email" => "a@example.com" }, "HTTP_X_FORWARDED_FOR" => "1.0.0.1, 203.0.113.9"
      expect(last_response.status).to eq(202)
      post_json "/api/v1/signup", { "email" => "b@example.com" }, "HTTP_X_FORWARDED_FOR" => "1.0.0.2, 203.0.113.9"
      expect(last_response.status).to eq(429)
    end

    it "prefers Fly-Client-IP over X-Forwarded-For for throttling" do
      ENV["SIGNUP_DAILY_IP_LIMIT"] = "1"
      allow(Mailer).to receive(:send_verification).and_return(:logged)
      post_json "/api/v1/signup", { "email" => "a@example.com" },
                "HTTP_FLY_CLIENT_IP" => "198.51.100.42", "HTTP_X_FORWARDED_FOR" => "1.0.0.1, 10.0.0.1"
      expect(last_response.status).to eq(202)
      post_json "/api/v1/signup", { "email" => "b@example.com" },
                "HTTP_FLY_CLIENT_IP" => "198.51.100.42", "HTTP_X_FORWARDED_FOR" => "1.0.0.2, 10.0.0.2"
      expect(last_response.status).to eq(429)
    end
  end

  describe "POST /api/v1/verify (step 2: confirm + issue key)" do
    it "consumes the emailed token and issues a working ak_ key" do
      token = signup_and_capture_token("dev@example.com")
      expect(token).to start_with("vs_")

      post_json "/api/v1/verify", { "token" => token }
      expect(last_response.status).to eq(201)
      data = parsed.fetch("data")
      key = data.fetch("token")
      expect(key).to start_with("ak_")
      expect(data.fetch("tier")).to eq("free")
      expect(data).not_to have_key("email")
      expect(data).not_to have_key("id")

      post_json "/api/v1/charts", TAIPEI.merge("lang" => "en"), "HTTP_AUTHORIZATION" => "Bearer #{key}"
      expect(last_response.status).to eq(200)
      expect(parsed.dig("data", "chart")).to have_key("planets")
    end

    it "defaults the issued key's monthly_limit to nil (unlimited)" do
      ENV.delete("SIGNUP_MONTHLY_LIMIT")
      token = signup_and_capture_token("nolimit@example.com")
      post_json "/api/v1/verify", { "token" => token }
      expect(parsed.dig("data", "monthly_limit")).to be_nil
    end

    it "honors SIGNUP_MONTHLY_LIMIT on the issued key" do
      ENV["SIGNUP_MONTHLY_LIMIT"] = "500"
      token = signup_and_capture_token("capped@example.com")
      post_json "/api/v1/verify", { "token" => token }
      expect(parsed.dig("data", "monthly_limit")).to eq(500)
    end

    it "rejects an unknown token with 400 verification_invalid" do
      post_json "/api/v1/verify", { "token" => "vs_does_not_exist" }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("verification_invalid")
    end

    it "rejects an expired token with 400 verification_expired" do
      token = AstroWeb.store.create_pending_signup(
        email: "exp@example.com", ip: "1.1.1.1", ttl_seconds: -10
      )["token"]
      post_json "/api/v1/verify", { "token" => token }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("verification_expired")
    end

    it "cannot reuse a consumed token" do
      token = signup_and_capture_token("once@example.com")
      post_json "/api/v1/verify", { "token" => token }
      expect(last_response.status).to eq(201)
      post_json "/api/v1/verify", { "token" => token }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("verification_invalid")
    end
  end

  describe "pages" do
    it "renders GET /signup" do
      get "/signup"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("/api/v1/signup")
    end

    it "renders GET /verify" do
      get "/verify?token=vs_anything"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("/api/v1/verify")
    end
  end

  describe "Store#migrate! idempotent + additive upgrade" do
    it "adds email/created_ip + pending_signups to an old-schema DB and preserves rows" do
      dir = Dir.mktmpdir("astro-migrate")
      path = File.join(dir, "old.db")
      begin
        raw = SQLite3::Database.new(path)
        raw.execute_batch(<<~SQL)
          CREATE TABLE api_keys (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            token_hash    TEXT NOT NULL UNIQUE,
            prefix        TEXT NOT NULL,
            label         TEXT NOT NULL DEFAULT '',
            tier          TEXT NOT NULL DEFAULT 'free',
            monthly_limit INTEGER,
            created_at    TEXT NOT NULL,
            revoked_at    TEXT
          );
          CREATE TABLE usage_daily (
            key_id   INTEGER NOT NULL,
            day      TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            count    INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (key_id, day, endpoint)
          );
        SQL
        raw.execute(
          "INSERT INTO api_keys (token_hash, prefix, label, tier, monthly_limit, created_at) " \
          "VALUES ('abc123', 'ak_legacy00', 'legacy', 'free', 1000, '2025-01-01T00:00:00Z')"
        )
        raw.close

        store = Store.new(path)
        store.migrate! # re-run to prove idempotency

        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        cols = db.execute("PRAGMA table_info(api_keys)").map { |c| c["name"] }
        expect(cols).to include("email", "created_ip")
        expect(cols.count("email")).to eq(1)
        tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").map { |r| r["name"] }
        expect(tables).to include("pending_signups")
        row = db.execute("SELECT * FROM api_keys WHERE prefix = 'ak_legacy00'").first
        expect(row["label"]).to eq("legacy")
        expect(row["monthly_limit"]).to eq(1000)
        expect(row["email"]).to be_nil
        db.close

        pending = store.create_pending_signup(email: "new@example.com", ip: "1.2.3.4")
        expect(pending["token"]).to start_with("vs_")
        expect(store.consume_pending_signup(pending["token"])["status"]).to eq("ok")
      ensure
        FileUtils.remove_entry(dir) if File.directory?(dir)
      end
    end
  end
end
