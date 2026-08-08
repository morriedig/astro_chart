require_relative "astro_chart/version"
# NOTE: the Swiss Ephemeris C extension (astro_chart_ext) is NOT loaded here.
# The default backend is pure Ruby; the extension is required on demand by
# `AstroChart.backend = :swiss` so environments without a compiled extension
# still work out of the box.
require_relative "astro_chart/pure"
require_relative "astro_chart/ephemeris"
require_relative "astro_chart/zodiac"
require_relative "astro_chart/aspects"
require_relative "astro_chart/houses"
require_relative "astro_chart/time_conversion"
require_relative "astro_chart/planets"
require_relative "astro_chart/points"
require_relative "astro_chart/patterns"
require_relative "astro_chart/stats"
require_relative "astro_chart/synastry"
require_relative "astro_chart/chart"
require_relative "astro_chart/transits"
require_relative "astro_chart/progressions"
require_relative "astro_chart/composite"
require_relative "astro_chart/solar_return"
require_relative "astro_chart/draconic"
require_relative "astro_chart/astrocartography"
require_relative "astro_chart/fixed_stars"
require_relative "astro_chart/dignities"
require_relative "astro_chart/profection"
require_relative "astro_chart/transit_timing"
require_relative "astro_chart/solar_arc"
require_relative "astro_chart/lunar_return"
require_relative "astro_chart/horary"

module AstroChart
end
