require_relative "spec_helper"

# API key authentication, usage metering, quota, and the admin key API.
RSpec.describe "AstroWeb auth & usage" do
  def app
    AstroWeb
  end

  let(:taipei) do
    {
      "birth_date" => "1990-01-01", "birth_time" => "12:00",
      "latitude" => 25.033, "longitude" => 121.5654, "timezone" => "Asia/Taipei"
    }
  end

  def post_chart(headers = {})
    post "/api/v1/charts", JSON.generate(taipei), { "CONTENT_TYPE" => "application/json" }.merge(headers)
  end

  # Create a key directly through the store and return its plaintext token.
  def make_key(monthly_limit: nil, label: "test")
    AstroWeb.store.create_key(label: label, monthly_limit: monthly_limit)["token"]
  end

  around(:each) do |example|
    prev_mode = ENV["API_KEY_MODE"]
    prev_admin = ENV["ADMIN_TOKEN"]
    example.run
    ENV["API_KEY_MODE"] = prev_mode
    ENV["ADMIN_TOKEN"] = prev_admin
  end

  describe "open mode (default)" do
    before { ENV["API_KEY_MODE"] = "open" }

    it "allows anonymous calls" do
      post_chart
      expect(last_response.status).to eq(200)
    end

    it "records anonymous usage under key_id 0" do
      post_chart
      global = AstroWeb.store.global_usage(Time.now.utc.strftime("%Y-%m"))
      expect(global["total"]).to eq(1)
      expect(global["by_key"]).to have_key("anonymous")
    end

    it "accepts a valid key via Authorization: Bearer" do
      token = make_key
      post_chart("HTTP_AUTHORIZATION" => "Bearer #{token}")
      expect(last_response.status).to eq(200)
    end

    it "accepts a valid key via X-API-Key" do
      token = make_key
      post_chart("HTTP_X_API_KEY" => token)
      expect(last_response.status).to eq(200)
    end

    it "rejects an unknown key with 401 invalid_api_key" do
      post_chart("HTTP_AUTHORIZATION" => "Bearer ak_nope")
      expect(last_response.status).to eq(401)
      expect(JSON.parse(last_response.body).dig("error", "code")).to eq("invalid_api_key")
    end

    it "rejects a revoked key" do
      created = AstroWeb.store.create_key(label: "temp")
      AstroWeb.store.revoke_key(created["id"])
      post_chart("HTTP_AUTHORIZATION" => "Bearer #{created['token']}")
      expect(last_response.status).to eq(401)
    end

    it "attributes usage to the key that made the call" do
      token = make_key(label: "acme")
      post_chart("HTTP_AUTHORIZATION" => "Bearer #{token}")
      get "/api/v1/usage", {}, { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
      data = JSON.parse(last_response.body)["data"]
      expect(data["total"]).to eq(1)
      expect(data["by_endpoint"]).to eq({ "charts" => 1 })
    end
  end

  describe "required mode" do
    before { ENV["API_KEY_MODE"] = "required" }

    it "blocks anonymous calls with 401 key_required" do
      post_chart
      expect(last_response.status).to eq(401)
      expect(JSON.parse(last_response.body).dig("error", "code")).to eq("key_required")
    end

    it "allows calls with a valid key" do
      token = make_key
      post_chart("HTTP_AUTHORIZATION" => "Bearer #{token}")
      expect(last_response.status).to eq(200)
    end
  end

  describe "quota" do
    before { ENV["API_KEY_MODE"] = "open" }

    it "returns 429 quota_exceeded once the monthly limit is hit" do
      token = make_key(monthly_limit: 2)
      2.times { post_chart("HTTP_AUTHORIZATION" => "Bearer #{token}") }
      expect(last_response.status).to eq(200)

      post_chart("HTTP_AUTHORIZATION" => "Bearer #{token}")
      expect(last_response.status).to eq(429)
      expect(JSON.parse(last_response.body).dig("error", "code")).to eq("quota_exceeded")
    end

    it "does not count failed (non-200) requests toward usage" do
      token = make_key(monthly_limit: 5)
      post "/api/v1/charts", JSON.generate(taipei.merge("timezone" => "Bad/Zone")),
           { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{token}" }
      expect(last_response.status).to eq(400)
      expect(AstroWeb.store.month_count(1, Time.now.utc.strftime("%Y-%m"))).to eq(0)
    end
  end

  describe "usage endpoint" do
    it "requires a key even in open mode" do
      ENV["API_KEY_MODE"] = "open"
      get "/api/v1/usage"
      expect(last_response.status).to eq(401)
      expect(JSON.parse(last_response.body).dig("error", "code")).to eq("key_required")
    end

    it "reports limit and remaining" do
      token = make_key(monthly_limit: 100)
      post_chart("HTTP_AUTHORIZATION" => "Bearer #{token}")
      get "/api/v1/usage", {}, { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
      data = JSON.parse(last_response.body)["data"]
      expect(data["monthly_limit"]).to eq(100)
      expect(data["remaining"]).to eq(99)
    end
  end

  describe "admin API" do
    it "is disabled (503) when ADMIN_TOKEN is unset" do
      ENV.delete("ADMIN_TOKEN")
      get "/admin/api-keys"
      expect(last_response.status).to eq(503)
      expect(JSON.parse(last_response.body).dig("error", "code")).to eq("admin_disabled")
    end

    it "rejects a wrong token with 401" do
      ENV["ADMIN_TOKEN"] = "s3cret"
      get "/admin/api-keys", {}, { "HTTP_AUTHORIZATION" => "Bearer wrong" }
      expect(last_response.status).to eq(401)
      expect(JSON.parse(last_response.body).dig("error", "code")).to eq("admin_unauthorized")
    end

    it "creates, lists, and revokes keys with a valid token" do
      ENV["ADMIN_TOKEN"] = "s3cret"
      admin = { "HTTP_AUTHORIZATION" => "Bearer s3cret", "CONTENT_TYPE" => "application/json" }

      post "/admin/api-keys", JSON.generate("label" => "acme", "monthly_limit" => 1000), admin
      expect(last_response.status).to eq(201)
      created = JSON.parse(last_response.body)["data"]
      expect(created["token"]).to start_with("ak_")
      expect(created["monthly_limit"]).to eq(1000)

      get "/admin/api-keys", {}, admin
      list = JSON.parse(last_response.body)["data"]
      expect(list.length).to eq(1)
      expect(list.first).not_to have_key("token")
      expect(list.first).not_to have_key("token_hash")

      delete "/admin/api-keys/#{created['id']}", {}, admin
      expect(last_response.status).to eq(200)

      get "/admin/api-keys", {}, admin
      expect(JSON.parse(last_response.body)["data"].first["revoked_at"]).not_to be_nil
    end

    it "returns JSON 404 not_found when revoking an unknown id" do
      ENV["ADMIN_TOKEN"] = "s3cret"
      delete "/admin/api-keys/9999", {}, { "HTTP_AUTHORIZATION" => "Bearer s3cret" }
      expect(last_response.status).to eq(404)
      expect(last_response.headers["Content-Type"]).to include("json")
      expect(JSON.parse(last_response.body).dig("error", "code")).to eq("not_found")
    end

    it "reports global usage" do
      ENV["ADMIN_TOKEN"] = "s3cret"
      ENV["API_KEY_MODE"] = "open"
      post_chart
      get "/admin/usage", {}, { "HTTP_AUTHORIZATION" => "Bearer s3cret" }
      data = JSON.parse(last_response.body)["data"]
      expect(data["total"]).to eq(1)
      expect(data["by_endpoint"]).to eq({ "charts" => 1 })
    end

    it "serves the public /admin page without a token" do
      ENV["ADMIN_TOKEN"] = "s3cret"
      get "/admin"
      expect(last_response.status).to eq(200)
      expect(last_response.headers["Content-Type"]).to include("html")
    end
  end

  describe "localized auth errors" do
    it "returns key_required in English" do
      get "/api/v1/usage?lang=en"
      expect(JSON.parse(last_response.body).dig("error", "message")).to eq("This endpoint requires an API key")
    end
  end
end
