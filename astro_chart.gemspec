require_relative "lib/astro_chart/version"

Gem::Specification.new do |spec|
  spec.name          = "astro_chart"
  spec.version       = AstroChart::VERSION
  spec.authors       = ["Huang Yudi"]
  spec.summary       = "Pure-Ruby astrology chart calculation (planets, Placidus/whole-sign houses, " \
                       "aspects, synastry, transits, progressions, composite, solar returns)"
  spec.description   = "Astrology chart calculation in pure Ruby: apparent planetary longitudes " \
                       "(VSOP87D, ELP-2000/82B moon, Meeus Pluto), Placidus and whole-sign houses, " \
                       "retrograde flags, aspects, derived points (Part of Fortune, mean Lilith), " \
                       "aspect-pattern detection and element statistics, plus synastry, transits, " \
                       "secondary progressions, composite charts and solar returns. " \
                       "No C extension, no external data files. Implemented from public formulas " \
                       "(Meeus, Astronomical Algorithms 2nd ed.)."
  spec.homepage      = "https://github.com/morriedig/astro_chart"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE", "CHANGELOG.md", "astro_chart.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "tzinfo", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
