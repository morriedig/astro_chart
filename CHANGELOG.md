# Changelog

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
