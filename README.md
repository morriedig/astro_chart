<p align="center">
  <img src="logo.png" alt="AstroChart — Pure-Ruby astrology chart calculation" width="600">
</p>

# AstroChart

Pure-Ruby gem for astrology chart calculation: apparent planetary
longitudes, four house systems (Placidus, whole-sign, equal, Porphyry),
retrograde flags, major & minor aspects, derived points (福點/莉莉絲/映點),
aspect patterns, element statistics, essential dignities & almuten,
synastry, transits, transit timing, secondary progressions, solar arc
directions, composite & draconic charts, solar & lunar returns, and annual
profection.

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
The hosted web app and MCP server live in a separate repository and depend
on `astro_chart` as a normal gem.

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
      # 大三角 (with "element"), T三角/上帝之指/風箏 (with "apex"), 大十字,
      # 神祕矩形, 星群 (with "zodiac")
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

Four systems, via `Chart.new(..., house_system: ...)`:

| Code | System | Notes |
|------|--------|-------|
| `"P"` | Placidus (default) | time-based; undefined inside the polar circle (raises) |
| `"W"` | Whole Sign | cusps on sign boundaries from the ascendant's sign |
| `"E"` | Equal | cusp 1 = ASC, then +30°; the true MC is still reported |
| `"O"` | Porphyry | quadrant trisection between the four angles |

Any other value raises `ArgumentError`. `W`/`E`/`O` are pure ASC/MC geometry
and are defined at every latitude |lat| < 90° — including polar latitudes,
where Placidus is undefined. (`Ephemeris.houses` also accepts the ord aliases
`80`/`87`/`69`/`79`.)

### Aspects

Major: 合相 (0°, orb 15°), 六分相 (60°, orb 6°), 四分相 (90°, orb 8°), 三分相 (120°, orb 8°), 對分相 (180°, orb 10°).

Minor (opt-in via `Aspects.calculate(a, b, minor: true)`): 十二分相 (30°), 半四分相 (45°), 補八分相 (135°), 補十二分相/quincunx (150°) — tighter orbs, and they never shadow a major aspect.

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

### Transit Timing (行運精確時點)

The exact UTC instants, within a date range, when a transiting body perfects
an aspect to a natal point — the "when" that `Transits.against` (a snapshot)
can't give:

```ruby
events = AstroChart::TransitTiming.events(natal_chart, "2026-01-01", "2026-12-31")
events.first
#=> { "transit_planet" => "土星", "natal_planet" => "太陽",
#     "aspect_type" => "四分相", "jd" => 2461...,
#     "time_utc" => "2026-03-14T07:22:10Z", "transit_zodiac" => "牡羊座",
#     "retrograde" => false }
```

Found by bracket-and-bisect on the ephemeris, so it is robust through
retrograde stations — all three passes of an outer-planet contact are caught.
Options: `minor:` (also time the minor aspects), `step_days:` (sampling
stride, default 1.0), `bodies:` (restrict transiting bodies, e.g. drop `"月亮"`
to avoid the Moon's monthly hits). Events are sorted by time.

### Solar Arc Directions (太陽弧推運)

```ruby
result = AstroChart::SolarArc.directions(natal_chart, "2026-07-24")
result["arc"]              # degrees the chart is directed (~1° per year of life)
result["planets"]          # every natal point advanced rigidly by the arc
result["aspects_to_natal"] # directed→natal aspects, sorted by orb
```

The arc is the secondary-progressed Sun's travel since birth; unlike secondary
progressions, the whole chart moves at that single rate.

### Lunar Returns (月亮回歸)

```ruby
result = AstroChart::LunarReturn.for_date(natal_chart, "2026-07-24")
result["return_jd"]        # JD (UT) of the lunar return nearest the date
result["return_time_utc"]  # "2026-07-31T09:54:22Z"
result["chart"]            # full chart at that instant (relocatable)
```

The monthly (~27.32-day) analogue of the solar return.

### Draconic Charts (龍盤)

```ruby
positions = AstroChart::Planets.calculate_positions(jd)  # or any { name => longitude }
AstroChart::Draconic.positions(positions, north_node)    # shift so 北交點 = 0° 牡羊
AstroChart::Draconic.chart(positions, north_node)
#=> { "planets" => [{ "planet" =>, "zodiac" =>, "degree" =>, "total_degree" => }...],
#     "aspects" => [...] }   # draconic signs + inter-aspects
```

### Essential Dignities (必然尊貴)

Traditional 廟/旺/三分性/界/外觀 with the traditional rulerships, Dorothean
triplicities, and both Egyptian and Ptolemaic terms. Pure lookup tables.

```ruby
D = AstroChart::Dignities

D.of("火星", 5.0)                    # 火星 at 5° 牡羊
#=> { "planet" => "火星", "dignities" => ["廟", "外觀"],
#     "debilities" => [], "score" => 6 }

D.almuten(5.0, sect: :day)          #=> { "planet" => "太陽", "score" => 7, "tied" => ["太陽"] }

D.term_ruler(13.0, scheme: :ptolemaic) #=> "金星"   (:egyptian is the default)
D.domicile_ruler(215)  #=> "火星"    D.triplicity_ruler(5, sect: :night) #=> "木星"
D.face_ruler(120)      #=> "土星"    D.exaltation_ruler(5)               #=> "太陽"
```

Dignities score +5/+4/+3/+2/+1 (廟/旺/三分性/界/外觀); debilities 陷 (detriment),
弱 (fall). Rulers are the seven traditional planets (dignity theory predates
the outer planets), so these differ from `Zodiac.ruler`'s modern rulerships.

### Annual Profection (小限法)

```ruby
AstroChart::Profection.annual(ascendant_longitude, 36)
#=> { "age" => 36, "profected_house" => 1, "profected_sign" => "牡羊座",
#     "year_lord" => "火星" }

AstroChart::Profection.at(ascendant_longitude, "1990-01-01", "2026-08-05")
# derives the age from the two dates, then profects
```

Each completed year advances one whole sign from the ascendant; the
traditional ruler of the profected sign is the Lord of the Year (年主星).

### Patterns & Element Stats

Included in `Chart#generate` output, or usable standalone on any
`{ name => longitude }` hash:

```ruby
AstroChart::Patterns.detect(positions)
#=> [{ "pattern_type" => "大三角",   "planets" => [...], "element" => "火" },
#    { "pattern_type" => "T三角",    "planets" => [...], "apex" => "火星" },
#    { "pattern_type" => "大十字",   "planets" => [...] },
#    { "pattern_type" => "上帝之指", "planets" => [...], "apex" => "水星" },  # Yod
#    { "pattern_type" => "風箏",     "planets" => [...], "apex" => "月亮" },  # Kite
#    { "pattern_type" => "神祕矩形", "planets" => [...] },                   # Mystic Rectangle
#    { "pattern_type" => "星群",     "planets" => [...], "zodiac" => "牡羊座" }] # Stellium

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

# 映點 / 反映點 (antiscia / contra-antiscia)
AstroChart::Points.antiscion(15.0)        #=> 165.0  (across the 巨蟹–摩羯 axis)
AstroChart::Points.contra_antiscion(15.0) #=> 345.0  (across the 牡羊–天秤 axis)
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
AstroChart::Ephemeris.houses(jd, 25.033, 121.565, "E")   # Equal
AstroChart::Ephemeris.houses(jd, 25.033, 121.565, "O")   # Porphyry

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
- **House systems: Placidus (`"P"`), Whole Sign (`"W"`), Equal (`"E"`) and
  Porphyry (`"O"`)** on the pure backend. Other systems raise `ArgumentError`.
  Polar latitudes (|lat| ≳ 66.5°) raise `AstroChart::Pure::Core::DomainError`
  on Placidus — it is undefined there; use whole-sign, equal or Porphyry for
  polar charts. Porphyry shares the four angles with Placidus and trisects
  each quadrant; verified against those invariants.

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

The hosted web app and MCP server that build on this gem live in a
separate repository and depend on `astro_chart` as a normal gem.

## License

MIT
