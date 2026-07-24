# Changelog

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
