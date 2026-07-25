require "sqlite3"
require "securerandom"
require "digest"
require "fileutils"

# Durable storage for API keys and usage counters, backed by SQLite.
#
# Single process, low volume: one connection guarded by a mutex, WAL mode.
# Anonymous usage is recorded under key_id 0 (api_keys ids start at 1).
class Store
  ANONYMOUS_KEY_ID = 0
  TOKEN_PREFIX = "ak_".freeze

  def initialize(path = nil)
    @path = path || ENV["ASTRO_DB_PATH"] || File.expand_path("../data/astro.db", __dir__)
    FileUtils.mkdir_p(File.dirname(@path)) unless @path == ":memory:"
    @mutex = Mutex.new
    @db = SQLite3::Database.new(@path)
    @db.busy_timeout = 5000
    @db.results_as_hash = true
    @db.execute("PRAGMA journal_mode=WAL") unless @path == ":memory:"
    migrate!
  end

  # Idempotent + additive. CREATE TABLE IF NOT EXISTS establishes the base
  # schema on a fresh DB; the ALTER steps upgrade an existing production DB
  # (the Fly volume already holds the old schema) by adding new columns only
  # when they are absent. Never drops or rewrites — existing rows survive.
  def migrate!
    @mutex.synchronize do
      @db.execute_batch(<<~SQL)
        CREATE TABLE IF NOT EXISTS api_keys (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          token_hash    TEXT NOT NULL UNIQUE,
          prefix        TEXT NOT NULL,
          label         TEXT NOT NULL DEFAULT '',
          tier          TEXT NOT NULL DEFAULT 'free',
          monthly_limit INTEGER,
          created_at    TEXT NOT NULL,
          revoked_at    TEXT
        );
        CREATE TABLE IF NOT EXISTS usage_daily (
          key_id   INTEGER NOT NULL,
          day      TEXT NOT NULL,
          endpoint TEXT NOT NULL,
          count    INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (key_id, day, endpoint)
        );
        CREATE TABLE IF NOT EXISTS pending_signups (
          token_hash  TEXT NOT NULL PRIMARY KEY,
          email       TEXT NOT NULL,
          created_ip  TEXT,
          created_at  TEXT NOT NULL,
          expires_at  TEXT NOT NULL,
          consumed_at TEXT
        );
      SQL

      existing = @db.execute("PRAGMA table_info(api_keys)").map { |c| c["name"] }
      @db.execute("ALTER TABLE api_keys ADD COLUMN email TEXT") unless existing.include?("email")
      @db.execute("ALTER TABLE api_keys ADD COLUMN created_ip TEXT") unless existing.include?("created_ip")
    end
  end

  # Create a key. Returns the row PLUS the plaintext token, which is shown
  # exactly once (only its SHA-256 hash is stored).
  def create_key(label: "", tier: "free", monthly_limit: nil)
    token = TOKEN_PREFIX + SecureRandom.urlsafe_base64(24)
    prefix = token[0, 11]
    created_at = utc_now
    id = @mutex.synchronize do
      @db.execute(
        "INSERT INTO api_keys (token_hash, prefix, label, tier, monthly_limit, created_at) " \
        "VALUES (?, ?, ?, ?, ?, ?)",
        [hash_token(token), prefix, label.to_s, tier.to_s, monthly_limit, created_at]
      )
      @db.last_insert_row_id
    end
    {
      "id" => id, "token" => token, "prefix" => prefix, "label" => label.to_s,
      "tier" => tier.to_s, "monthly_limit" => monthly_limit, "created_at" => created_at
    }
  end

  # Self-serve key issued from the public signup endpoint. Same shape as
  # create_key (plaintext token shown once) but records the developer's
  # email + originating IP for support/abuse handling; tier is "free".
  # email/created_ip are operator-only — never surfaced on public endpoints.
  def create_signup_key(email:, ip:, monthly_limit: nil)
    token = TOKEN_PREFIX + SecureRandom.urlsafe_base64(24)
    prefix = token[0, 11]
    created_at = utc_now
    id = @mutex.synchronize do
      @db.execute(
        "INSERT INTO api_keys (token_hash, prefix, label, tier, monthly_limit, created_at, email, created_ip) " \
        "VALUES (?, ?, ?, 'free', ?, ?, ?, ?)",
        [hash_token(token), prefix, "self-serve", monthly_limit, created_at, email.to_s, ip.to_s]
      )
      @db.last_insert_row_id
    end
    {
      "id" => id, "token" => token, "prefix" => prefix, "label" => "self-serve",
      "tier" => "free", "monthly_limit" => monthly_limit, "created_at" => created_at
    }
  end

  # Number of keys created today (UTC) from a given IP — used to throttle
  # self-serve signup abuse.
  def signups_from_ip_today(ip)
    day = Time.now.utc.strftime("%Y-%m-%d")
    rows = @mutex.synchronize do
      @db.execute(
        "SELECT COUNT(*) AS n FROM api_keys WHERE created_ip = ? AND substr(created_at, 1, 10) = ?",
        [ip.to_s, day]
      )
    end
    rows.first["n"].to_i
  end

  # Look up an active (non-revoked) key by its plaintext token. nil if the
  # token is unknown or the key was revoked.
  def find_key_by_token(token)
    return nil if token.nil? || token.empty?

    rows = @mutex.synchronize do
      @db.execute(
        "SELECT * FROM api_keys WHERE token_hash = ? AND revoked_at IS NULL LIMIT 1",
        [hash_token(token)]
      )
    end
    rows.first
  end

  def list_keys
    @mutex.synchronize do
      @db.execute(
        "SELECT id, prefix, label, tier, monthly_limit, created_at, revoked_at, email " \
        "FROM api_keys ORDER BY id DESC"
      )
    end
  end

  # Revoke a key. Returns true if a live key was revoked.
  def revoke_key(id)
    @mutex.synchronize do
      @db.execute(
        "UPDATE api_keys SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL",
        [utc_now, id.to_i]
      )
      @db.changes.positive?
    end
  end

  def record_usage(key_id, endpoint, day)
    @mutex.synchronize do
      @db.execute(
        "INSERT INTO usage_daily (key_id, day, endpoint, count) VALUES (?, ?, ?, 1) " \
        "ON CONFLICT(key_id, day, endpoint) DO UPDATE SET count = count + 1",
        [key_id.to_i, day, endpoint]
      )
    end
  end

  # Total calls for a key within a "YYYY-MM" month.
  def month_count(key_id, month)
    rows = @mutex.synchronize do
      @db.execute(
        "SELECT COALESCE(SUM(count), 0) AS n FROM usage_daily " \
        "WHERE key_id = ? AND substr(day, 1, 7) = ?",
        [key_id.to_i, month]
      )
    end
    rows.first["n"].to_i
  end

  # Usage summary for one key in a given month: total, per-endpoint, per-day,
  # plus the key's limit/remaining.
  def usage_summary(key, month)
    rows = @mutex.synchronize do
      @db.execute(
        "SELECT day, endpoint, count FROM usage_daily " \
        "WHERE key_id = ? AND substr(day, 1, 7) = ?",
        [key["id"].to_i, month]
      )
    end
    total = 0
    by_endpoint = Hash.new(0)
    by_day = Hash.new(0)
    rows.each do |r|
      c = r["count"].to_i
      total += c
      by_endpoint[r["endpoint"]] += c
      by_day[r["day"]] += c
    end
    limit = key["monthly_limit"]
    {
      "key" => {
        "prefix" => key["prefix"], "label" => key["label"], "tier" => key["tier"],
      },
      "month" => month,
      "total" => total,
      "monthly_limit" => limit,
      "remaining" => limit.nil? ? nil : [limit.to_i - total, 0].max,
      "by_endpoint" => by_endpoint.sort_by { |_, v| -v }.to_h,
      "by_day" => by_day.sort.to_h,
    }
  end

  # Aggregate usage across all keys for a month (admin view).
  def global_usage(month)
    rows = @mutex.synchronize do
      @db.execute(
        "SELECT key_id, endpoint, SUM(count) AS n FROM usage_daily " \
        "WHERE substr(day, 1, 7) = ? GROUP BY key_id, endpoint",
        [month]
      )
    end
    total = 0
    by_endpoint = Hash.new(0)
    by_key = Hash.new(0)
    rows.each do |r|
      n = r["n"].to_i
      total += n
      by_endpoint[r["endpoint"]] += n
      by_key[r["key_id"].to_i] += n
    end
    {
      "month" => month,
      "total" => total,
      "by_endpoint" => by_endpoint.sort_by { |_, v| -v }.to_h,
      "by_key" => by_key.transform_keys { |k| k.zero? ? "anonymous" : k }
                        .sort_by { |_, v| -v }.to_h,
    }
  end

  # --- Email verification (double opt-in) ---

  # Stage a signup pending email confirmation. Returns the plaintext
  # verification token (emailed as a link; only its hash is stored) and
  # the expiry. No API key exists yet — one is issued on consume.
  def create_pending_signup(email:, ip:, ttl_seconds: 86_400)
    token = "vs_" + SecureRandom.urlsafe_base64(24)
    now = Time.now.utc
    expires_at = (now + ttl_seconds).strftime("%Y-%m-%dT%H:%M:%SZ")
    @mutex.synchronize do
      @db.execute(
        "INSERT INTO pending_signups (token_hash, email, created_ip, created_at, expires_at) " \
        "VALUES (?, ?, ?, ?, ?)",
        [hash_token(token), email.to_s, ip.to_s, now.strftime("%Y-%m-%dT%H:%M:%SZ"), expires_at]
      )
    end
    { "token" => token, "expires_at" => expires_at }
  end

  # Consume a verification token exactly once. Returns:
  #   {"status" => "ok", "email" =>, "ip" =>}  on success (marks consumed)
  #   {"status" => "expired"}                   token past its expiry
  #   {"status" => "invalid"}                   unknown or already consumed
  def consume_pending_signup(token)
    return { "status" => "invalid" } if token.nil? || token.empty?

    now = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    @mutex.synchronize do
      row = @db.execute(
        "SELECT email, created_ip, expires_at, consumed_at FROM pending_signups " \
        "WHERE token_hash = ? LIMIT 1", [hash_token(token)]
      ).first
      return { "status" => "invalid" } if row.nil? || row["consumed_at"]
      return { "status" => "expired" } if row["expires_at"] < now

      @db.execute(
        "UPDATE pending_signups SET consumed_at = ? WHERE token_hash = ?",
        [now, hash_token(token)]
      )
      { "status" => "ok", "email" => row["email"], "ip" => row["created_ip"] }
    end
  end

  # Pending verification requests created today (UTC) from an IP — throttles
  # signup email sends (abuse / mail-bombing).
  def pending_signups_from_ip_today(ip)
    day = Time.now.utc.strftime("%Y-%m-%d")
    rows = @mutex.synchronize do
      @db.execute(
        "SELECT COUNT(*) AS n FROM pending_signups WHERE created_ip = ? AND substr(created_at, 1, 10) = ?",
        [ip.to_s, day]
      )
    end
    rows.first["n"].to_i
  end

  # Test helper: wipe all rows.
  def reset!
    @mutex.synchronize do
      @db.execute("DELETE FROM api_keys")
      @db.execute("DELETE FROM usage_daily")
      @db.execute("DELETE FROM pending_signups")
      @db.execute("DELETE FROM sqlite_sequence WHERE name = 'api_keys'")
    end
  end

  private

  def hash_token(token)
    Digest::SHA256.hexdigest(token)
  end

  def utc_now
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end
end
