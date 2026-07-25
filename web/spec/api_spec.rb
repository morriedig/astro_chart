require_relative "spec_helper"
require "time"

RSpec.describe "AstroWeb API" do
  def app
    AstroWeb
  end

  VALID_PARAMS = {
    "birth_date" => "1990-01-01",
    "birth_time" => "12:00",
    "latitude" => 25.033,
    "longitude" => 121.5654,
    "timezone" => "Asia/Taipei",
  }.freeze

  OTHER_PARAMS = {
    "birth_date" => "1985-06-15",
    "birth_time" => "08:30",
    "latitude" => 35.6762,
    "longitude" => 139.6503,
    "timezone" => "Asia/Tokyo",
  }.freeze

  def post_json(path, payload)
    body = payload.is_a?(String) ? payload : JSON.generate(payload)
    post path, body, "CONTENT_TYPE" => "application/json"
  end

  def parsed_body
    JSON.parse(last_response.body)
  end

  def expect_api_error(code)
    expect(last_response.status).to eq(400)
    expect(last_response.content_type).to include("application/json")
    error = parsed_body.fetch("error")
    expect(error.fetch("code")).to eq(code)
    expect(error.fetch("message")).to be_a(String)
    expect(error.fetch("message")).not_to be_empty
  end

  describe "POST /api/v1/charts" do
    context "happy path" do
      before { post_json "/api/v1/charts", VALID_PARAMS }

      it "returns 200 JSON" do
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include("application/json")
      end

      it "places the Sun in Capricorn (摩羯座)" do
        sun = parsed_body.dig("data", "chart", "planets")
                         .find { |p| p["planet"] == "太陽" }
        expect(sun).not_to be_nil
        expect(sun.fetch("zodiac")).to eq("摩羯座")
      end

      it "returns all 17 planet entries in the documented order" do
        planets = parsed_body.dig("data", "chart", "planets")
        expect(planets.map { |p| p["planet"] }).to eq(
          [
            "太陽", "月亮", "水星", "金星", "火星", "木星", "土星",
            "天王星", "海王星", "冥王星", "北交點", "南交點",
            "福點", "莉莉絲",
            "北交點定位星", "南交點定位星", "上升星座定位星",
          ]
        )
      end

      it "flags 水星/金星/木星 retrograde on 1990-01-01 and nothing else" do
        planets = parsed_body.dig("data", "chart", "planets")
        retro = planets.select { |p| p["retrograde"] }.map { |p| p["planet"] }
        expect(retro).to match_array(%w[水星 金星 木星])
      end

      it "gives every planet entry a boolean retrograde key" do
        planets = parsed_body.dig("data", "chart", "planets")
        expect(planets.map { |p| p["retrograde"] }).to all(be(true).or(be(false)))
      end

      it "shapes 福點 and 莉莉絲 like regular point entries" do
        planets = parsed_body.dig("data", "chart", "planets")
        %w[福點 莉莉絲].each do |name|
          point = planets.find { |p| p["planet"] == name }
          expect(point).to include("planet", "zodiac", "house", "degree", "total_degree", "retrograde")
          expect(point.fetch("retrograde")).to be(false)
          expect(point.fetch("house")).to be_between(1, 12)
          expect(point.fetch("total_degree")).to be_between(0, 360)
        end
      end

      it "defaults house_system to P" do
        expect(parsed_body.dig("data", "chart", "house_system")).to eq("P")
      end

      it "returns a patterns array" do
        expect(parsed_body.dig("data", "chart", "patterns")).to be_an(Array)
      end

      it "returns element_stats over the 10 classical planets" do
        stats = parsed_body.dig("data", "chart", "element_stats")
        expect(stats.fetch("elements").values.sum).to eq(10)
        expect(stats.fetch("modalities").values.sum).to eq(10)
        expect(stats.fetch("elements").keys).to eq(%w[火 土 風 水])
        expect(stats.fetch("modalities").keys).to eq(%w[基本 固定 變動])
      end

      it "returns 12 houses" do
        houses = parsed_body.dig("data", "chart", "houses")
        expect(houses.size).to eq(12)
        expect(houses.map { |h| h["house_number"] }).to match_array((1..12).to_a)
      end

      it "returns the ascendant with zodiac/degree/total_degree keys" do
        ascendant = parsed_body.dig("data", "chart", "ascendant")
        expect(ascendant).to include("zodiac", "degree", "total_degree")
      end

      it "echoes the input back" do
        input = parsed_body.dig("data", "input")
        expect(input).to eq(
          "birth_date" => "1990-01-01",
          "birth_time" => "12:00",
          "coordinates" => { "latitude" => 25.033, "longitude" => 121.5654 },
          "timezone" => "Asia/Taipei"
        )
      end

      it "includes the CORS header" do
        expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
      end
    end

    context "house systems" do
      it "returns whole-sign cusps all at sign boundaries for house_system W" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("house_system" => "W")
        expect(last_response.status).to eq(200)
        chart = parsed_body.dig("data", "chart")
        expect(chart.fetch("house_system")).to eq("W")
        degrees = chart.fetch("houses").map { |h| h["degree"] }
        expect(degrees).to all(satisfy("be a multiple of 30") { |d| (d % 30).zero? })
      end

      it "keeps the ascendant identical between P and W" do
        post_json "/api/v1/charts", VALID_PARAMS
        placidus_asc = parsed_body.dig("data", "chart", "ascendant")
        post_json "/api/v1/charts", VALID_PARAMS.merge("house_system" => "W")
        expect(parsed_body.dig("data", "chart", "ascendant")).to eq(placidus_asc)
      end

      it "normalizes the whole_sign alias" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("house_system" => "whole_sign")
        expect(last_response.status).to eq(200)
        expect(parsed_body.dig("data", "chart", "house_system")).to eq("W")
      end

      it "normalizes the placidus alias" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("house_system" => "Placidus")
        expect(last_response.status).to eq(200)
        expect(parsed_body.dig("data", "chart", "house_system")).to eq("P")
      end

      it "returns invalid_house_system for K" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("house_system" => "K")
        expect_api_error("invalid_house_system")
      end

      it "returns invalid_house_system for a non-string" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("house_system" => 42)
        expect_api_error("invalid_house_system")
      end
    end

    context "error cases" do
      it "returns invalid_json for a malformed body" do
        post_json "/api/v1/charts", "{not json"
        expect_api_error("invalid_json")
      end

      it "returns missing_param when birth_time is omitted" do
        post_json "/api/v1/charts", VALID_PARAMS.reject { |k, _| k == "birth_time" }
        expect_api_error("missing_param")
      end

      it "returns invalid_date for an impossible date (1990-13-40)" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("birth_date" => "1990-13-40")
        expect_api_error("invalid_date")
      end

      it "returns invalid_date for a wrong date format (01/01/1990)" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("birth_date" => "01/01/1990")
        expect_api_error("invalid_date")
      end

      it "returns invalid_time for 25:00" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("birth_time" => "25:00")
        expect_api_error("invalid_time")
      end

      it "returns invalid_coordinates for a non-numeric latitude" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("latitude" => "abc")
        expect_api_error("invalid_coordinates")
      end

      it "returns invalid_coordinates for latitude 95" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("latitude" => 95)
        expect_api_error("invalid_coordinates")
      end

      it "returns invalid_timezone for Asia/NotAPlace" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("timezone" => "Asia/NotAPlace")
        expect_api_error("invalid_timezone")
      end

      it "returns polar_latitude for latitude 78.0" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("latitude" => 78.0)
        expect_api_error("polar_latitude")
      end

      it "returns date_out_of_range for 1800-01-01" do
        post_json "/api/v1/charts", VALID_PARAMS.merge("birth_date" => "1800-01-01")
        expect_api_error("date_out_of_range")
      end

      it "returns invalid_time for a DST spring-forward gap time" do
        post_json "/api/v1/charts", VALID_PARAMS.merge(
          "birth_date" => "2021-03-14", "birth_time" => "02:30",
          "latitude" => 40.7128, "longitude" => -74.006,
          "timezone" => "America/New_York"
        )
        expect_api_error("invalid_time")
      end

      it "returns invalid_time for a DST fall-back ambiguous time" do
        post_json "/api/v1/charts", VALID_PARAMS.merge(
          "birth_date" => "2021-11-07", "birth_time" => "01:30",
          "latitude" => 40.7128, "longitude" => -74.006,
          "timezone" => "America/New_York"
        )
        expect_api_error("invalid_time")
      end
    end
  end

  describe "POST /api/v1/synastry" do
    context "happy path with orb_limit 6" do
      before do
        post_json "/api/v1/synastry",
                  "a" => VALID_PARAMS, "b" => OTHER_PARAMS, "orb_limit" => 6.0
      end

      it "returns 200 with a_chart, b_chart and synastry keys" do
        expect(last_response.status).to eq(200)
        data = parsed_body.fetch("data")
        expect(data.keys).to include("a_chart", "b_chart", "synastry")
        expect(data.dig("a_chart", "chart", "planets")).to be_an(Array)
        expect(data.dig("b_chart", "chart", "planets")).to be_an(Array)
      end

      it "returns aspects sorted by orb ascending" do
        aspects = parsed_body.dig("data", "synastry", "aspects")
        expect(aspects).to be_an(Array)
        expect(aspects).not_to be_empty
        orbs = aspects.map { |a| a.fetch("orb") }
        expect(orbs).to eq(orbs.sort)
      end

      it "keeps every aspect orb within the orb_limit" do
        aspects = parsed_body.dig("data", "synastry", "aspects")
        expect(aspects.map { |a| a.fetch("orb") }).to all(be <= 6.0)
      end

      it "places overlay planets in houses 1..12" do
        %w[a_planets_in_b_houses b_planets_in_a_houses].each do |key|
          overlay = parsed_body.dig("data", "synastry", key)
          expect(overlay).to be_a(Hash)
          expect(overlay).not_to be_empty
          expect(overlay.values).to all(be_between(1, 12))
        end
      end
    end

    it "works without orb_limit" do
      post_json "/api/v1/synastry", "a" => VALID_PARAMS, "b" => OTHER_PARAMS
      expect(last_response.status).to eq(200)
      aspects = parsed_body.dig("data", "synastry", "aspects")
      expect(aspects).to be_an(Array)
      expect(parsed_body.fetch("data").keys).to include("a_chart", "b_chart", "synastry")
    end

    it "accepts house_system inside a and b" do
      post_json "/api/v1/synastry",
                "a" => VALID_PARAMS.merge("house_system" => "W"),
                "b" => OTHER_PARAMS.merge("house_system" => "whole_sign")
      expect(last_response.status).to eq(200)
      expect(parsed_body.dig("data", "a_chart", "chart", "house_system")).to eq("W")
      expect(parsed_body.dig("data", "b_chart", "chart", "house_system")).to eq("W")
    end

    it "returns invalid_house_system for a bad house_system inside a" do
      post_json "/api/v1/synastry",
                "a" => VALID_PARAMS.merge("house_system" => "K"), "b" => OTHER_PARAMS
      expect_api_error("invalid_house_system")
    end

    it "rejects a non-numeric orb_limit without blaming the JSON" do
      post_json "/api/v1/synastry",
                "a" => VALID_PARAMS, "b" => OTHER_PARAMS, "orb_limit" => "6"
      expect_api_error("missing_param")
    end
  end

  describe "POST /api/v1/transits" do
    context "with an explicit at moment" do
      before do
        post_json "/api/v1/transits",
                  "natal" => VALID_PARAMS,
                  "at" => { "date" => "2026-07-24", "time" => "12:00", "timezone" => "Asia/Taipei" }
      end

      it "returns 200 with natal_chart, transit_time_utc, planets and aspects" do
        expect(last_response.status).to eq(200)
        data = parsed_body.fetch("data")
        expect(data.keys).to eq(%w[natal_chart transit_time_utc planets aspects])
        expect(data.dig("natal_chart", "chart", "planets").size).to eq(17)
      end

      it "converts the local at moment to UTC" do
        expect(parsed_body.dig("data", "transit_time_utc")).to eq("2026-07-24T04:00:00Z")
      end

      it "places the late-July transiting Sun in 獅子座" do
        sun = parsed_body.dig("data", "planets").find { |p| p["planet"] == "太陽" }
        expect(sun.fetch("zodiac")).to eq("獅子座")
      end

      it "returns the 12 transiting bodies placed in natal houses" do
        planets = parsed_body.dig("data", "planets")
        expect(planets.size).to eq(12)
        expect(planets.map { |p| p["natal_house"] }).to all(be_between(1, 12))
      end

      it "keeps aspects within the default orb 3 and sorted ascending" do
        orbs = parsed_body.dig("data", "aspects").map { |a| a.fetch("orb") }
        expect(orbs).to all(be <= 3.0)
        expect(orbs).to eq(orbs.sort)
      end
    end

    context "without at (defaults to now, UTC)" do
      before { post_json "/api/v1/transits", "natal" => VALID_PARAMS }

      it "returns 200 with an ISO8601 UTC transit_time_utc close to now" do
        expect(last_response.status).to eq(200)
        stamp = parsed_body.dig("data", "transit_time_utc")
        expect(stamp).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        expect((Time.now.utc - Time.parse(stamp)).abs).to be < 60
      end

      it "still returns 12 transit planets" do
        expect(parsed_body.dig("data", "planets").size).to eq(12)
      end
    end

    it "honours a custom orb_limit" do
      post_json "/api/v1/transits",
                "natal" => VALID_PARAMS, "orb_limit" => 1.0,
                "at" => { "date" => "2026-07-24", "time" => "12:00", "timezone" => "Asia/Taipei" }
      orbs = parsed_body.dig("data", "aspects").map { |a| a.fetch("orb") }
      expect(orbs).to all(be <= 1.0)
    end

    it "returns invalid_date for a malformed at.date" do
      post_json "/api/v1/transits",
                "natal" => VALID_PARAMS,
                "at" => { "date" => "24/07/2026", "time" => "12:00", "timezone" => "Asia/Taipei" }
      expect_api_error("invalid_date")
    end

    it "returns missing_param when at.time is omitted" do
      post_json "/api/v1/transits",
                "natal" => VALID_PARAMS,
                "at" => { "date" => "2026-07-24", "timezone" => "Asia/Taipei" }
      expect_api_error("missing_param")
    end

    it "returns invalid_time for a DST spring-forward at moment" do
      post_json "/api/v1/transits",
                "natal" => VALID_PARAMS,
                "at" => { "date" => "2021-03-14", "time" => "02:30", "timezone" => "America/New_York" }
      expect_api_error("invalid_time")
    end

    it "returns missing_param when natal is omitted" do
      post_json "/api/v1/transits", "at" => { "date" => "2026-07-24", "time" => "12:00", "timezone" => "Asia/Taipei" }
      expect_api_error("missing_param")
    end
  end

  describe "POST /api/v1/progressions" do
    context "happy path 30 years after birth" do
      before do
        post_json "/api/v1/progressions",
                  "natal" => VALID_PARAMS, "target_date" => "2020-01-01"
      end

      it "returns 200 with natal_chart and progression" do
        expect(last_response.status).to eq(200)
        expect(parsed_body.fetch("data").keys).to eq(%w[natal_chart progression])
      end

      it "reports 30 elapsed years" do
        expect(parsed_body.dig("data", "progression", "years_elapsed")).to be_within(0.05).of(30.0)
      end

      it "progresses the Sun about one sign forward (摩羯座 -> 水瓶座)" do
        natal_sun = parsed_body.dig("data", "natal_chart", "chart", "planets")
                               .find { |p| p["planet"] == "太陽" }
        prog_sun = parsed_body.dig("data", "progression", "planets")
                              .find { |p| p["planet"] == "太陽" }
        expect(natal_sun.fetch("zodiac")).to eq("摩羯座")
        expect(prog_sun.fetch("zodiac")).to eq("水瓶座")
        drift = (prog_sun["total_degree"] - natal_sun["total_degree"]) % 360
        expect(drift).to be_between(28, 32)
      end

      it "keeps aspects_to_natal within the default orb 1 and sorted" do
        orbs = parsed_body.dig("data", "progression", "aspects_to_natal").map { |a| a.fetch("orb") }
        expect(orbs).to all(be <= 1.0)
        expect(orbs).to eq(orbs.sort)
      end
    end

    it "returns missing_param when target_date is omitted" do
      post_json "/api/v1/progressions", "natal" => VALID_PARAMS
      expect_api_error("missing_param")
    end

    it "returns invalid_date for a malformed target_date" do
      post_json "/api/v1/progressions", "natal" => VALID_PARAMS, "target_date" => "2020-13-40"
      expect_api_error("invalid_date")
    end
  end

  describe "POST /api/v1/composite" do
    context "happy path" do
      before { post_json "/api/v1/composite", "a" => VALID_PARAMS, "b" => OTHER_PARAMS }

      it "returns 200 with a_chart, b_chart and composite" do
        expect(last_response.status).to eq(200)
        expect(parsed_body.fetch("data").keys).to eq(%w[a_chart b_chart composite])
      end

      it "returns 12 composite bodies with zodiac names" do
        planets = parsed_body.dig("data", "composite", "planets")
        expect(planets.size).to eq(12)
        expect(planets.map { |p| p["zodiac"] }).to all(match(/座\z/))
      end

      it "places the composite Sun at the shorter-arc midpoint of both Suns" do
        sun_of = lambda do |chart_key|
          parsed_body.dig("data", chart_key, "chart", "planets")
                     .find { |p| p["planet"] == "太陽" }
                     .fetch("total_degree")
        end
        a = sun_of.call("a_chart")
        b = sun_of.call("b_chart")
        expected = (a + (((b - a + 540.0) % 360.0) - 180.0) / 2.0) % 360.0
        composite_sun = parsed_body.dig("data", "composite", "planets")
                                   .find { |p| p["planet"] == "太陽" }
        expect(composite_sun.fetch("total_degree")).to be_within(0.001).of(expected)
      end

      it "sorts composite aspects by orb ascending" do
        orbs = parsed_body.dig("data", "composite", "aspects").map { |a| a.fetch("orb") }
        expect(orbs).to eq(orbs.sort)
      end
    end

    it "returns missing_param when b is omitted" do
      post_json "/api/v1/composite", "a" => VALID_PARAMS
      expect_api_error("missing_param")
    end
  end

  describe "POST /api/v1/solar-return" do
    context "happy path for 2026" do
      before { post_json "/api/v1/solar-return", "natal" => VALID_PARAMS, "year" => 2026 }

      it "returns 200 with natal_chart and solar_return" do
        expect(last_response.status).to eq(200)
        expect(parsed_body.fetch("data").keys).to eq(%w[natal_chart solar_return])
      end

      it "returns the Sun to its natal longitude" do
        natal_sun = parsed_body.dig("data", "natal_chart", "chart", "planets")
                               .find { |p| p["planet"] == "太陽" }
        sr_sun = parsed_body.dig("data", "solar_return", "chart", "planets")
                            .find { |p| p["planet"] == "太陽" }
        expect(sr_sun.fetch("zodiac")).to eq(natal_sun.fetch("zodiac"))
        expect(sr_sun.fetch("total_degree")).to be_within(0.01).of(natal_sun.fetch("total_degree"))
      end

      it "returns an ISO8601 UTC return time near the birthday" do
        stamp = parsed_body.dig("data", "solar_return", "return_time_utc")
        expect(stamp).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        expect(Date.parse(stamp[0, 10])).to be_between(Date.new(2025, 12, 29), Date.new(2026, 1, 4))
      end

      it "defaults the location to the natal coordinates" do
        location = parsed_body.dig("data", "solar_return", "location")
        expect(location.fetch("latitude")).to eq(25.033)
        expect(location.fetch("longitude")).to eq(121.5654)
        expect(location.fetch("timezone")).to eq("Asia/Taipei")
      end
    end

    it "supports relocation overrides" do
      post_json "/api/v1/solar-return",
                "natal" => VALID_PARAMS, "year" => 2026,
                "latitude" => 35.6762, "longitude" => 139.6503, "timezone" => "Asia/Tokyo"
      expect(last_response.status).to eq(200)
      location = parsed_body.dig("data", "solar_return", "location")
      expect(location).to eq(
        "latitude" => 35.6762, "longitude" => 139.6503, "timezone" => "Asia/Tokyo"
      )
    end

    it "returns date_out_of_range for a year outside the ephemeris range" do
      post_json "/api/v1/solar-return", "natal" => VALID_PARAMS, "year" => 2150
      expect_api_error("date_out_of_range")
    end

    it "returns missing_param when year is omitted" do
      post_json "/api/v1/solar-return", "natal" => VALID_PARAMS
      expect_api_error("missing_param")
    end

    it "returns missing_param for a non-integer year" do
      post_json "/api/v1/solar-return", "natal" => VALID_PARAMS, "year" => "2026"
      expect_api_error("missing_param")
    end

    it "returns invalid_coordinates for an out-of-range latitude override" do
      post_json "/api/v1/solar-return", "natal" => VALID_PARAMS, "year" => 2026, "latitude" => 95
      expect_api_error("invalid_coordinates")
    end
  end

  describe "GET /api/v1/cities" do
    it "finds 台北市 by English prefix" do
      get "/api/v1/cities", "q" => "taipei"
      expect(last_response.status).to eq(200)
      results = parsed_body.fetch("data")
      expect(results.first).to eq(
        "name" => "台北市", "country" => "台灣",
        "latitude" => 25.0330, "longitude" => 121.5654, "timezone" => "Asia/Taipei"
      )
    end

    it "finds 東京 by Chinese name" do
      get "/api/v1/cities", "q" => "東京"
      names = parsed_body.fetch("data").map { |c| c["name"] }
      expect(names).to eq(["東京"])
    end

    it "matches case-insensitively" do
      get "/api/v1/cities", "q" => "TOKYO"
      expect(parsed_body.fetch("data").map { |c| c["name"] }).to include("東京")
    end

    it "ranks prefix matches before substring matches" do
      get "/api/v1/cities", "q" => "lon"
      names = parsed_body.fetch("data").map { |c| c["name"] }
      expect(names.first).to eq("倫敦")
      expect(names).to include("巴塞隆納")
    end

    it "caps results at 10" do
      get "/api/v1/cities", "q" => "a"
      expect(parsed_body.fetch("data").size).to eq(10)
    end

    it "never exposes the alt key" do
      get "/api/v1/cities", "q" => "taipei"
      expect(parsed_body.fetch("data")).to all(satisfy { |c| !c.key?("alt") })
    end

    it "returns missing_param when q is absent" do
      get "/api/v1/cities"
      expect_api_error("missing_param")
    end

    it "returns missing_param when q is blank" do
      get "/api/v1/cities", "q" => "  "
      expect_api_error("missing_param")
    end

    it "returns an empty list for an unmatched query" do
      get "/api/v1/cities", "q" => "atlantis-nowhere"
      expect(last_response.status).to eq(200)
      expect(parsed_body.fetch("data")).to eq([])
    end
  end

  describe "GET /openapi.json" do
    it "serves the static spec when present, 404 otherwise" do
      get "/openapi.json"
      if File.file?(File.expand_path("../public/openapi.json", __dir__))
        expect(last_response.status).to eq(200)
        expect { JSON.parse(last_response.body) }.not_to raise_error
      else
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe "GET /api/v1/health" do
    it "returns 200 with status ok" do
      get "/api/v1/health"
      expect(last_response.status).to eq(200)
      expect(parsed_body.fetch("status")).to eq("ok")
      expect(parsed_body.fetch("gem_version")).to eq(AstroChart::VERSION)
    end
  end

  describe "CORS" do
    it "answers OPTIONS /api/v1/charts with 204 and preflight headers" do
      options "/api/v1/charts"
      expect(last_response.status).to eq(204)
      expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(last_response.headers["Access-Control-Allow-Methods"]).to eq("POST,GET,OPTIONS")
      expect(last_response.headers["Access-Control-Allow-Headers"]).to eq("Content-Type, Authorization, X-API-Key")
    end
  end

  describe "unknown API path" do
    it "returns 404 JSON with code not_found" do
      get "/api/v1/nope"
      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include("application/json")
      expect(parsed_body.dig("error", "code")).to eq("not_found")
    end

    it "returns the CORS header on the bare /api path" do
      get "/api"
      expect(last_response.status).to eq(404)
      expect(parsed_body.dig("error", "code")).to eq("not_found")
      expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end
  end

  describe "HTML pages" do
    it "serves GET / as HTML" do
      get "/"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/html")
    end

    it "serves GET /docs as HTML" do
      get "/docs"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/html")
    end
  end
end
