require_relative "lib/astro_chart/version"

Gem::Specification.new do |spec|
  spec.name          = "astro_chart"
  spec.version       = AstroChart::VERSION
  spec.authors       = ["Huang Yudi"]
  spec.summary       = "Pure-Ruby natal chart calculation (planets, Placidus houses, aspects, synastry)"
  spec.description   = "Natal astrology chart calculation in pure Ruby: apparent planetary longitudes " \
                       "(VSOP87D, ELP-2000/82B moon, Meeus Pluto), Placidus houses, aspects and synastry. " \
                       "No C extension, no external data files. Implemented from public formulas " \
                       "(Meeus, Astronomical Algorithms 2nd ed.)."
  spec.homepage      = "https://github.com/morriedig/astro_chart"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "LICENSE", "CHANGELOG.md", "astro_chart.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "tzinfo", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
