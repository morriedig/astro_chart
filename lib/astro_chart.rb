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
require_relative "astro_chart/synastry"
require_relative "astro_chart/chart"

module AstroChart
end
