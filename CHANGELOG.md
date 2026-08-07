# Changelog

## 0.5.0 (2026-08-07)

**Astrocartography (星象地圖).** All pure Ruby, additive.

- New `AstroChart::Astrocartography.lines(jd)` — the relocational map lines for
  the ten bodies at a birth instant: the MC and IC meridian longitudes, and
  the ASC (rising) and DSC (setting) horizon curves as latitude/longitude
  segments (broken where a body is circumpolar). Built from the body's RA/Dec
  and Greenwich apparent sidereal time; verified independently (body altitude
  ≈ 0 along every ASC/DSC point, LST = RA on the MC). Ecliptic latitude is
  approximated as 0 (exact for the Sun; largest error for the Moon/Pluto).

## 0.4.0 (2026-08-06)

**Traditional dignities, transit timing, two more house systems, minor
aspects, four new configurations, antiscia, draconic charts, solar arc,
lunar & annual predictive tools.** All pure Ruby, additive and
backward-compatible.

- **Minor aspects**: `Aspects.calculate(a, b, minor: true)` also matches
  十二分相 (30°), 半四分相 (45°), 補八分相 (135°) and 補十二分相 (quincunx,
  150°). Default stays major-only; minor aspects carry tighter orbs and never
  shadow a major one.
- **New aspect patterns** in `Patterns.detect` (and every `Chart#generate`
  output): 上帝之指 (Yod: sextile base + quincunx apex), 風箏 (Kite: a 大三角
  plus an opposing/sextiling focal body, reported alongside the trine), 神祕
  矩形 (Mystic Rectangle: two oppositions joined by sextiles and trines) and
  星群 (Stellium: 3+ bodies in one sign). Existing 大三角/T三角/大十字 output is
  unchanged; the node-axis exclusion rules extend to the new configurations.
- **Antiscia**: `Points.antiscion` (reflection across the 巨蟹–摩羯 solstice
  axis) and `Points.contra_antiscion` (across the 牡羊–天秤 equinox axis).
- **Draconic charts (龍盤)**: new `AstroChart::Draconic` — `.positions` shifts
  every longitude so the natal 北交點 sits at 0° 牡羊; `.chart` adds draconic
  signs, in-sign degrees and inter-aspects.
- **Two more house systems**: Equal (`"E"`, from the ascendant) and Porphyry
  (`"O"`, quadrant trisection), joining Placidus (`"P"`) and Whole Sign
  (`"W"`). Both are pure geometry off the ASC/MC and are defined at every
  latitude |lat| < 90° (including inside the polar circle, where Placidus
  raises). Ord aliases 69/79 mirror the C-extension int argument.
- **Essential dignities (必然尊貴)**: new `AstroChart::Dignities` — 廟/旺/三分性/
  界/外觀 with the traditional rulerships and Dorothean triplicities.
  `.of(planet, longitude, sect:)` reports a planet's dignities/debilities and
  Lilly-weighted score (+5/+4/+3/+2/+1); `.almuten(longitude, sect:)` returns
  the winning planet at a degree; plus `.domicile_ruler`/`detriment_ruler`/
  `exaltation_ruler`/`fall_ruler`/`triplicity_ruler`/`term_ruler`/`face_ruler`.
  界 ships both 埃及界 (Egyptian, `scheme: :egyptian`, the default) and 托勒密界
  (Ptolemaic, `scheme: :ptolemaic`); both are cross-validated against Astrolog
  and the Egyptian table matches several independent references.
- **Annual profection (小限法)**: new `AstroChart::Profection` — `.annual(asc,
  age)` and `.at(asc, birth_date, target_date)` give the profected house/sign
  and Lord of the Year (年主星).
- **Transit timing (行運精確時點)**: new `AstroChart::TransitTiming.events` —
  the exact UTC instants in a date range when a transiting body perfects an
  aspect to a natal point, found by bracket-and-bisect on the ephemeris
  (robust through retrograde stations, so all three passes of an outer-planet
  contact are caught). `minor:`, `step_days:` and `bodies:` options.
- **Solar arc directions (太陽弧推運)**: new `AstroChart::SolarArc.directions`
  — directs the whole chart rigidly by the secondary-progressed Sun's arc and
  reports directed-to-natal aspects.
- **Lunar returns (月亮回歸)**: new `AstroChart::LunarReturn.for_date` — the
  chart at the Moon's monthly return to its natal longitude, relocatable like
  the solar return.

## 0.3.0 (2026-07-24)

**Predictive & comparison modules, whole-sign houses, retrograde flags,
derived points, pattern detection.** All pure Ruby, MIT.

- **Whole-sign houses**: `Chart.new(..., house_system: "W")` ("P" Placidus
  remains the default; anything else raises `ArgumentError`). Whole-sign
  works at all latitudes |lat| < 90° (including polar latitudes, where
  Placidus still raises); Placidus output is byte-identical to 0.2.0.
  `Ephemeris.houses` / `Pure.houses` accept `"W"` too.
- **Retrograde flags**: every planet entry in `Chart#generate` gains
  `"retrograde" => true/false` (central-difference daily motion via the new
  `Ephemeris.speed(jd, id)` / `Ephemeris.retrograde?(jd, id)`). 太陽/月亮
  are hard-false, 南交點 mirrors 北交點, derived/ruler points are false.
  Within half a day of a body's valid ephemeris window edge (e.g. the
  Pluto series' 1885–2099 range) the speed stencil falls back to a
  one-sided difference, so edge-of-range charts still generate.
- **Derived points** (`AstroChart::Points`): 福點 (Part of Fortune,
  day/night formula; sect judged from the horizon — ASC–DSC axis — so it
  is independent of the display house system) and 莉莉絲 (mean Black Moon
  Lilith, Meeus mean lunar apogee + 180°, verified < 0.13° vs Swiss
  Ephemeris across 1900–2050). Both appended to `Chart#generate` planets,
  before the ruler points.
- **Transits** (`AstroChart::Transits`): `.at(jd)` sky snapshot;
  `.against(natal, jd, orb_limit: 3.0)` places transiting bodies in natal
  houses and lists transit-to-natal aspects sorted by orb.
- **Secondary progressions** (`AstroChart::Progressions`):
  `.secondary(natal, "YYYY-MM-DD", orb_limit: 1.0)` — day-for-a-year
  progressed positions, natal house placement, aspects to natal.
- **Composite charts** (`AstroChart::Composite`): `.between(a, b)` —
  shorter-arc midpoint chart of two natal charts, with internal aspects.
- **Solar returns** (`AstroChart::SolarReturn`): `.for_year(natal, year,
  latitude:, longitude:, timezone:)` — Newton-iterated exact return
  instant, full relocated chart at that moment.
- **Aspect patterns** (`AstroChart::Patterns.detect`): 大三角 (with
  element), T三角 (with apex), 大十字; node-axis oppositions excluded
  from opposition legs; 大十字 subsumes its own T三角s; an opposition
  squared by the node axis is reported as a single T三角 (apex 北交點)
  rather than mirrored 北/南交點 twins. `Chart#generate` now includes
  `"patterns"`.
- **Element statistics** (`AstroChart::Stats.elements`): 火土風水 element
  and 基本固定變動 modality counts over the 10 classical planets.
  `Chart#generate` now includes `"element_stats"` and `"house_system"`.
- `Houses.calculate` now takes the house system as a keyword
  (`system: "P"`).

## 0.2.0 (2026-07-24)

**License change: AGPL-3.0 → MIT.**

- New pure-Ruby ephemeris backend, now the default (`AstroChart.backend == :pure`):
  - Planets: VSOP87D truncated series (Sun, Mercury–Neptune)
  - Moon & true node: ELP-2000/82B truncated series (CDS VizieR VI/79)
  - Pluto: Meeus Astronomical Algorithms Ch. 37 series (valid 1885–2099)
  - Placidus houses, ΔT (Espenak & Meeus), IAU 1980 nutation
  - Verified against Swiss Ephemeris 1900–2026: all bodies within
    0.014° (most < 0.001°), zero zodiac sign flips
- New `AstroChart::Synastry`: cross-chart aspects + house overlay
- **Removed** the bundled Swiss Ephemeris C extension (AGPL). The
  `:swiss` backend now raises `LoadError` unless you compile and provide
  the extension yourself (it is no longer shipped with this gem).
- Pure backend supports Placidus ("P") houses only; polar latitudes
  raise `AstroChart::Pure::Core::DomainError` explicitly.
- Public interface unchanged: `Ephemeris.julday / calc_ut / houses`,
  `Chart#generate` output structure identical.

## 0.1.0

- Initial release (Swiss Ephemeris C extension, AGPL-3.0).
