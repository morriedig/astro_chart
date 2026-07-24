# AstroChart

Pure-Ruby gem for astrology chart calculation: apparent planetary
longitudes, Placidus & whole-sign houses, retrograde flags, aspects,
derived points (福點/莉莉絲), aspect patterns, element statistics,
synastry, transits, secondary progressions, composite charts, and solar
returns.

**No C extension, no external data files, MIT licensed.** Implemented from
public formulas (Jean Meeus, *Astronomical Algorithms* 2nd ed.; VSOP87D;
ELP-2000/82B), verified against Swiss Ephemeris to < 0.014° (most bodies
< 0.001°) across 1900–2026 with zero zodiac sign flips.

## Hosted Service（線上服務）

A live web UI and open JSON API built on this gem:

- **Web 星盤查詢**: https://astro-chart-api.fly.dev/ （本命盤、合盤、行運、二次推運、組合盤、太陽回歸，繁體中文）
- **API 文件**: https://astro-chart-api.fly.dev/docs
- Currently in open beta: no API key, no rate limit, free. CORS enabled.

```bash
curl -X POST https://astro-chart-api.fly.dev/api/v1/charts \
  -H "Content-Type: application/json" \
  -d '{"birth_date":"1990-01-01","birth_time":"12:00",
       "latitude":25.033,"longitude":121.5654,"timezone":"Asia/Taipei"}'
```

Endpoints: `POST /api/v1/charts` (natal chart), `POST /api/v1/synastry`
(合盤), `POST /api/v1/transits` (行運), `POST /api/v1/progressions`
(二次推運), `POST /api/v1/composite` (組合盤), `POST /api/v1/solar-return`
(太陽回歸), `GET /api/v1/cities` (城市搜尋), `GET /api/v1/health`.
Source lives in [`web/`](web/) — a Sinatra app deployed on Fly.io (see
`Dockerfile` / `fly.toml` at the repo root).

## Installation

```ruby
gem "astro_chart", "~> 0.3"
```

Then `bundle install`. Nothing to compile.

## Usage

```ruby
require "astro_chart"

chart = AstroChart::Chart.new(
  birth_date: "1990-01-01",
  birth_time: "12:00",
  latitude:   25.0330,
  longitude:  121.5654,
  timezone:   "Asia/Taipei",
  house_system: "P"          # "P" Placidus (default) or "W" Whole Sign
)

result = chart.generate
```

### Return Value

`generate` returns a Hash with string keys:

```ruby
{
  "input" => {
    "birth_date"  => "1990-01-01",
    "birth_time"  => "12:00",
    "coordinates" => { "latitude" => 25.033, "longitude" => 121.5654 },
    "timezone"    => "Asia/Taipei"
  },
  "chart" => {
    "ascendant" => {
      "zodiac"       => "牡羊座",
      "degree"       => 16.4422,
      "total_degree" => 16.4422
    },
    "house_system" => "P",
    "planets" => [
      {
        "planet"       => "太陽",
        "zodiac"       => "摩羯座",
        "house"        => 9,
        "degree"       => 10.4744,
        "total_degree" => 280.4744,
        "retrograde"   => false,
        "aspects"      => [
          { "planet" => "土星", "aspect_type" => "合相", "orb" => 5.14 }
        ]
      },
      # ... 月亮, 水星, 金星, 火星, 木星, 土星, 天王星, 海王星, 冥王星,
      #     北交點, 南交點, 福點, 莉莉絲,
      #     北交點定位星, 南交點定位星, 上升星座定位星  (17 entries)
    ],
    "houses" => [
      { "house_number" => 1, "degree" => 16.4422, "zodiac" => "牡羊座" },
      # ... 2-12
    ],
    "patterns" => [
      { "pattern_type" => "T三角", "planets" => ["太陽", "月亮", "火星"],
        "apex" => "火星" }
      # 大三角 (with "element"), T三角 (with "apex"), 大十字
    ],
    "element_stats" => {
      "elements"   => { "火" => 1, "土" => 5, "風" => 2, "水" => 2 },
      "modalities" => { "基本" => 6, "固定" => 3, "變動" => 1 }
    }
  }
}
```

### Planets Included

太陽, 月亮, 水星, 金星, 火星, 木星, 土星, 天王星, 海王星, 冥王星, 北交點（真交點）, 南交點

Plus derived points 福點 (Part of Fortune) and 莉莉絲 (mean Black Moon
Lilith), and three ruler points: 北交點定位星, 南交點定位星, 上升星座定位星
— 17 entries total, in that order.

Every entry carries `"retrograde"` (central-difference daily motion;
太陽/月亮 and derived/ruler points are always `false`, 南交點 mirrors
北交點).

### House Systems

Placidus (`"P"`, default) and Whole Sign (`"W"`), via
`Chart.new(..., house_system: "W")`. Any other value raises
`ArgumentError`. Whole-sign cusps sit on sign boundaries starting at the
ascendant's sign and work at every latitude |lat| < 90° — including polar
latitudes, where Placidus is undefined.

### Aspects

合相 (0°, orb 15°), 六分相 (60°, orb 6°), 四分相 (90°, orb 8°), 三分相 (120°, orb 8°), 對分相 (180°, orb 10°)

### Synastry (合盤)

```ruby
result = AstroChart::Synastry.between(chart_a, chart_b, orb_limit: 6.0)

result["aspects"]
#=> [{ "a_planet" => "太陽", "b_planet" => "月亮",
#      "aspect_type" => "三分相", "orb" => 1.23 }, ...]  # sorted by orb

result["a_planets_in_b_houses"]  #=> { "太陽" => 7, ... }  (house overlay)
result["b_planets_in_a_houses"]  #=> { "月亮" => 12, ... }
```

Lower-level: `Synastry.cross_aspects(positions_a, positions_b)` and
`Synastry.house_overlay(positions, cusps)` work on raw longitude hashes.

### Transits (行運)

```ruby
jd = AstroChart::TimeConversion.to_julian_day("2026-07-24", "12:00", "Asia/Taipei")

AstroChart::Transits.at(jd)
#=> { "太陽" => 121.9, ... }  # sky snapshot, 12 bodies

result = AstroChart::Transits.against(natal_chart, jd, orb_limit: 3.0)
result["planets"]  # 12 transiting bodies with "natal_house"
result["aspects"]  # [{ "transit_planet" => "土星", "natal_planet" => "太陽",
                   #    "aspect_type" => "四分相", "orb" => 1.23 }, ...] sorted by orb
```

### Secondary Progressions (二次推運)

```ruby
result = AstroChart::Progressions.secondary(natal_chart, "2026-07-24", orb_limit: 1.0)
result["progressed_jd"]     # day-for-a-year progressed Julian Day
result["years_elapsed"]     # e.g. 36.56
result["planets"]           # progressed positions + natal house placement
result["aspects_to_natal"]  # [{ "progressed_planet" => ..., "natal_planet" => ... }]
```

### Composite Charts (組合盤)

```ruby
result = AstroChart::Composite.between(chart_a, chart_b)
result["planets"]  # shorter-arc midpoints of the 12 bodies
result["aspects"]  # aspects among the composite positions, sorted by orb
```

(No composite houses — midpoint houses are not well-defined.)

### Solar Returns (太陽回歸)

```ruby
result = AstroChart::SolarReturn.for_year(natal_chart, 2026)
result["return_jd"]        # exact JD (UT) the Sun returns to its natal longitude
result["return_time_utc"]  # "2026-07-03T05:12:34Z"
result["chart"]            # full chart at that instant (relocate with
                           # latitude:/longitude:/timezone: overrides)
```

### Patterns & Element Stats

Included in `Chart#generate` output, or usable standalone on any
`{ name => longitude }` hash:

```ruby
AstroChart::Patterns.detect(positions)
#=> [{ "pattern_type" => "大三角", "planets" => [...], "element" => "火" },
#    { "pattern_type" => "T三角",  "planets" => [...], "apex" => "火星" },
#    { "pattern_type" => "大十字", "planets" => [...] }]

AstroChart::Stats.elements(positions)
#=> { "elements"   => { "火" => 3, "土" => 2, "風" => 3, "水" => 2 },
#    "modalities" => { "基本" => 4, "固定" => 3, "變動" => 3 } }
```

### Derived Points

```ruby
AstroChart::Points.lilith(jd)  #=> 216.47 (mean Black Moon Lilith, 0-360)
AstroChart::Points.fortune(asc: asc, sun: sun, moon: moon, day_chart: true)
AstroChart::Points.day_chart?(sun_longitude, cusps)  #=> true / false / nil
AstroChart::Points.day_chart_from_horizon?(sun_longitude, ascendant)
# Chart#generate determines 福點 sect from the horizon (ASC-DSC axis),
# so the same birth instant yields the same 福點 under "P" and "W".
```

### Individual Modules

```ruby
# Zodiac sign from ecliptic longitude
AstroChart::Zodiac.sign_name(280.5)  #=> "摩羯座"
AstroChart::Zodiac.ruler("摩羯座")    #=> "土星"

# Aspect between two positions
AstroChart::Aspects.calculate(0, 90)  #=> ["四分相", 0.0]

# Julian Day conversion
jd = AstroChart::TimeConversion.to_julian_day("1990-01-01", "12:00", "Asia/Taipei")

# Raw ephemeris access (planet ids follow the SE convention)
AstroChart::Ephemeris.julday(2000, 1, 1, 12.0)
AstroChart::Ephemeris.calc_ut(jd, AstroChart::Ephemeris::PLANETS["太陽"])
AstroChart::Ephemeris.houses(jd, 25.033, 121.565)        # Placidus
AstroChart::Ephemeris.houses(jd, 25.033, 121.565, "W")   # Whole Sign

# Daily motion / retrograde detection
AstroChart::Ephemeris.speed(jd, 2)        #=> degrees/day (negative = retrograde)
AstroChart::Ephemeris.retrograde?(jd, 2)  #=> true / false
```

## Backends

The default backend is `:pure` (pure Ruby, always available). The legacy
Swiss Ephemeris C extension backend can still be selected **if you compile
and provide the extension yourself** — it is no longer shipped with this gem
(it is AGPL-licensed, see 0.1.x):

```ruby
AstroChart.backend          #=> :pure
AstroChart.backend = :swiss # raises LoadError unless the extension is present
```

## Accuracy & Limits

- Verified against Swiss Ephemeris (Moshier), 1900–2026, 400 samples per
  body: Sun ≤ 0.0002°, Moon ≤ 0.0013°, planets ≤ 0.0006°, Pluto ≤ 0.0005°,
  true node ≤ 0.014°, house cusps ≤ 0.0003°. Zero zodiac sign flips.
- 莉莉絲 (mean Black Moon Lilith) uses the Meeus mean lunar perigee
  polynomial + 180°; verified ≤ 0.13° vs Swiss Ephemeris across 1900–2050.
- Whole-sign cusps verified identical to Swiss Ephemeris, including inside
  the polar circle. Retrograde flags verified against Swiss central-difference
  speeds (Mercury 2020–2024, every sample matches).
- Transit / progression / solar-return positions verified within 0.003° of
  Swiss Ephemeris at sampled instants (1962–2033).
- Pluto series is valid 1885–2099 (raises outside this range).
- **House systems: Placidus (`"P"`) and Whole Sign (`"W"`)** on the pure
  backend. Other systems raise `ArgumentError`. Polar latitudes
  (|lat| ≳ 66.5°) raise `AstroChart::Pure::Core::DomainError` on Placidus —
  it is undefined there; use whole-sign for polar charts.

## Geocoding

This gem does **not** handle geocoding. Pass latitude, longitude, and
timezone directly. For city-to-coordinate conversion, use the
[geocoder](https://github.com/alexreisner/geocoder) gem or your own lookup
table.

## Development

```bash
bundle install
rake spec
```

### Web app (`web/`)

```bash
cd web
bundle install
bundle exec rackup -p 9292   # http://localhost:9292
bundle exec rspec            # request specs
```

Deploy: `fly deploy` from the repo root (config in `fly.toml`; the Docker
build context is the repo root because `web/Gemfile` references the gem
via `path: ".."`).

## License

MIT
