require_relative "spec_helper"
require "sqlite3"
require "tmpdir"
require "fileutils"

RSpec.describe "AstroWeb self-serve signup" do
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

  around(:each) do |example|
    prev_limit = ENV["SIGNUP_DAILY_IP_LIMIT"]
    prev_monthly = ENV["SIGNUP_MONTHLY_LIMIT"]
    prev_mode = ENV["API_KEY_MODE"]
    example.run
    ENV["SIGNUP_DAILY_IP_LIMIT"] = prev_limit
    ENV["SIGNUP_MONTHLY_LIMIT"] = prev_monthly
    ENV["API_KEY_MODE"] = prev_mode
  end

  describe "POST /api/v1/signup" do
    it "issues an ak_ key that then works on /api/v1/charts" do
      post_json "/api/v1/signup", { "email" => "dev@example.com" }
      expect(last_response.status).to eq(201)
      expect(last_response.content_type).to include("application/json")

      data = parsed.fetch("data")
      token = data.fetch("token")
      expect(token).to start_with("ak_")
      expect(data.fetch("prefix")).to start_with("ak_")
      expect(data.fetch("tier")).to eq("free")
      expect(data).to have_key("monthly_limit")
      # Public response never leaks email or the internal id.
      expect(data).not_to have_key("email")
      expect(data).not_to have_key("id")

      # The key authenticates a real billable call and is attributed.
      post_json "/api/v1/charts", TAIPEI.merge("lang" => "en"),
                "HTTP_AUTHORIZATION" => "Bearer #{token}"
      expect(last_response.status).to eq(200)
      expect(parsed.dig("data", "chart")).to have_key("planets")
    end

    it "defaults monthly_limit to nil (unlimited) when SIGNUP_MONTHLY_LIMIT is unset" do
      ENV.delete("SIGNUP_MONTHLY_LIMIT")
      post_json "/api/v1/signup", { "email" => "nolimit@example.com" }
      expect(last_response.status).to eq(201)
      expect(parsed.dig("data", "monthly_limit")).to be_nil
    end

    it "honors SIGNUP_MONTHLY_LIMIT when set" do
      ENV["SIGNUP_MONTHLY_LIMIT"] = "500"
      post_json "/api/v1/signup", { "email" => "capped@example.com" }
      expect(last_response.status).to eq(201)
      expect(parsed.dig("data", "monthly_limit")).to eq(500)
    end

    it "rejects a malformed email with 400 invalid_email" do
      post_json "/api/v1/signup", { "email" => "not-an-email" }
      expect(last_response.status).to eq(400)
      error = parsed.fetch("error")
      expect(error.fetch("code")).to eq("invalid_email")
      expect(error.fetch("message")).not_to be_empty
    end

    it "localizes the invalid_email message via lang" do
      post_json "/api/v1/signup", { "email" => "bad", "lang" => "en" }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("invalid_email")
      expect(parsed.dig("error", "message")).to eq("Invalid email address format")
    end

    it "throttles by IP once SIGNUP_DAILY_IP_LIMIT is reached (429)" do
      ENV["SIGNUP_DAILY_IP_LIMIT"] = "2"
      ip = "203.0.113.7"
      2.times do |i|
        post_json "/api/v1/signup", { "email" => "user#{i}@example.com" },
                  "HTTP_X_FORWARDED_FOR" => ip
        expect(last_response.status).to eq(201)
      end

      post_json "/api/v1/signup", { "email" => "user3@example.com" },
                "HTTP_X_FORWARDED_FOR" => ip
      expect(last_response.status).to eq(429)
      expect(parsed.dig("error", "code")).to eq("signup_rate_limited")
    end

    it "keys the throttle on the LAST X-Forwarded-For hop (trusted proxy), not the spoofable first" do
      ENV["SIGNUP_DAILY_IP_LIMIT"] = "1"
      # Fly appends the real client IP to the END of X-Forwarded-For; the first
      # entry is attacker-controlled. Rotating the first hop must NOT bypass the
      # cap when the trusted (last) hop is the same real client.
      post_json "/api/v1/signup", { "email" => "a@example.com" },
                "HTTP_X_FORWARDED_FOR" => "1.0.0.1, 203.0.113.9"
      expect(last_response.status).to eq(201)

      post_json "/api/v1/signup", { "email" => "b@example.com" },
                "HTTP_X_FORWARDED_FOR" => "1.0.0.2, 203.0.113.9"
      expect(last_response.status).to eq(429)
    end

    it "prefers the Fly-Client-IP header over X-Forwarded-For" do
      ENV["SIGNUP_DAILY_IP_LIMIT"] = "1"
      # Same trusted Fly-Client-IP across spoofed XFF chains => second throttled.
      post_json "/api/v1/signup", { "email" => "a@example.com" },
                "HTTP_FLY_CLIENT_IP" => "198.51.100.42",
                "HTTP_X_FORWARDED_FOR" => "1.0.0.1, 10.0.0.1"
      expect(last_response.status).to eq(201)

      post_json "/api/v1/signup", { "email" => "b@example.com" },
                "HTTP_FLY_CLIENT_IP" => "198.51.100.42",
                "HTTP_X_FORWARDED_FOR" => "1.0.0.2, 10.0.0.2"
      expect(last_response.status).to eq(429)
    end

    it "rejects an oversized email (over 254 chars) with 400 invalid_email" do
      long = ("a" * 250) + "@" + ("b" * 250) + ".com"
      post_json "/api/v1/signup", { "email" => long }
      expect(last_response.status).to eq(400)
      expect(parsed.dig("error", "code")).to eq("invalid_email")
    end
  end

  describe "GET /signup" do
    it "renders the standalone signup page" do
      get "/signup"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("/api/v1/signup")
      expect(last_response.body).to include("取得 API 金鑰")
    end
  end

  describe "Store#migrate! idempotent + additive upgrade" do
    it "adds email/created_ip to an old-schema DB and preserves existing rows" do
      dir = Dir.mktmpdir("astro-migrate")
      path = File.join(dir, "old.db")
      begin
        # Build the ORIGINAL (pre-signup) schema by hand — no email/created_ip.
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

        probe = SQLite3::Database.new(path)
        cols_before = probe.execute("PRAGMA table_info(api_keys)").map { |c| c[1] }
        probe.close
        expect(cols_before).not_to include("email")
        expect(cols_before).not_to include("created_ip")

        # Opening a Store runs migrate! — must upgrade cleanly.
        store = Store.new(path)
        store.migrate! # re-run to prove idempotency (no error, no dup columns)

        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        cols_after = db.execute("PRAGMA table_info(api_keys)").map { |c| c["name"] }
        expect(cols_after).to include("email")
        expect(cols_after).to include("created_ip")
        # email column appears exactly once (idempotent, not duplicated).
        expect(cols_after.count("email")).to eq(1)

        # The legacy row survived, new columns default to NULL.
        row = db.execute("SELECT * FROM api_keys WHERE prefix = 'ak_legacy00'").first
        expect(row["label"]).to eq("legacy")
        expect(row["monthly_limit"]).to eq(1000)
        expect(row["email"]).to be_nil
        db.close

        # And the upgraded DB now supports self-serve signup writes.
        key = store.create_signup_key(email: "new@example.com", ip: "1.2.3.4")
        expect(key["token"]).to start_with("ak_")
        expect(store.signups_from_ip_today("1.2.3.4")).to eq(1)
      ensure
        FileUtils.remove_entry(dir) if File.directory?(dir)
      end
    end
  end
end
