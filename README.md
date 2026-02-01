# AstroChart

Ruby gem for natal astrology chart calculation, powered by Swiss Ephemeris.

Uses the **Moshier ephemeris** mode — no external data files needed. Just compile and run.

## Installation

```ruby
gem "astro_chart", "~> 0.1.0"
```

Then `bundle install`. The C extension will compile automatically.

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

太陽, 月亮, 水星, 金星, 火星, 木星, 土星, 天王星, 海王星, 冥王星, 北交點, 南交點

Plus three ruler points: 北交點定位星, 南交點定位星, 上升星座定位星

### Aspects

合相 (0°, orb 15°), 六分相 (60°, orb 6°), 四分相 (90°, orb 8°), 三分相 (120°, orb 8°), 對分相 (180°, orb 10°)

### Individual Modules

```ruby
# Zodiac sign from ecliptic longitude
AstroChart::Zodiac.sign_name(280.5)  #=> "摩羯座"
AstroChart::Zodiac.ruler("摩羯座")    #=> "土星"

# Aspect between two positions
AstroChart::Aspects.calculate(0, 90)  #=> ["四分相", 0.0]

# Julian Day conversion
jd = AstroChart::TimeConversion.to_julian_day("1990-01-01", "12:00", "Asia/Taipei")

# Raw Swiss Ephemeris access
AstroChart::Ephemeris.julday(2000, 1, 1, 12.0)
AstroChart::Ephemeris.calc_ut(jd, AstroChart::Ext::SUN)
AstroChart::Ephemeris.houses(jd, 25.033, 121.565)
```

## Geocoding

This gem does **not** handle geocoding. Pass latitude, longitude, and timezone directly. For city-to-coordinate conversion, use the [geocoder](https://github.com/alexreisner/geocoder) gem or your own lookup table.

## House System

Defaults to **Placidus**. Pass a different system code to `Houses.calculate`:

```ruby
AstroChart::Houses.calculate(jd, lat, lon, "W")  # Whole sign
AstroChart::Houses.calculate(jd, lat, lon, "K")  # Koch
```

## Development

```bash
bundle install
rake compile
rake spec
```

## License

AGPL-3.0 (required by Swiss Ephemeris)
