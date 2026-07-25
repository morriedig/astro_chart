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
      SQL
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
        "SELECT id, prefix, label, tier, monthly_limit, created_at, revoked_at " \
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

  # Test helper: wipe all rows.
  def reset!
    @mutex.synchronize do
      @db.execute("DELETE FROM api_keys")
      @db.execute("DELETE FROM usage_daily")
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
