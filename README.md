# AstroChart

Pure-Ruby gem for natal astrology chart calculation: apparent planetary
longitudes, Placidus houses, aspects, and synastry.

**No C extension, no external data files, MIT licensed.** Implemented from
public formulas (Jean Meeus, *Astronomical Algorithms* 2nd ed.; VSOP87D;
ELP-2000/82B), verified against Swiss Ephemeris to < 0.014° (most bodies
< 0.001°) across 1900–2026 with zero zodiac sign flips.

## Installation

```ruby
gem "astro_chart", "~> 0.2"
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
  timezone:   "Asia/Taipei"
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
    "planets" => [
      {
        "planet"       => "太陽",
        "zodiac"       => "摩羯座",
        "house"        => 9,
        "degree"       => 10.4744,
        "total_degree" => 280.4744,
        "aspects"      => [
          { "planet" => "土星", "aspect_type" => "合相", "orb" => 5.14 }
        ]
      },
      # ... 月亮, 水星, 金星, 火星, 木星, 土星, 天王星, 海王星, 冥王星,
      #     北交點, 南交點, 北交點定位星, 南交點定位星, 上升星座定位星
    ],
    "houses" => [
      { "house_number" => 1, "degree" => 16.4422, "zodiac" => "牡羊座" },
      # ... 2-12
    ]
  }
}
```

### Planets Included

太陽, 月亮, 水星, 金星, 火星, 木星, 土星, 天王星, 海王星, 冥王星, 北交點（真交點）, 南交點

Plus three ruler points: 北交點定位星, 南交點定位星, 上升星座定位星

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
AstroChart::Ephemeris.houses(jd, 25.033, 121.565)
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
- Pluto series is valid 1885–2099 (raises outside this range).
- **House system: Placidus only** on the pure backend (`"P"`). Other systems
  raise `ArgumentError`. Polar latitudes (|lat| ≳ 66.5°) raise
  `AstroChart::Pure::Core::DomainError` — Placidus is undefined there.

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

## License

MIT
