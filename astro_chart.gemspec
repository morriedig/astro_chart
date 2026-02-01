require_relative "lib/astro_chart/version"

Gem::Specification.new do |spec|
  spec.name          = "astro_chart"
  spec.version       = AstroChart::VERSION
  spec.authors       = ["Huang Yudi"]
  spec.summary       = "Natal chart calculation using Swiss Ephemeris"
  spec.description   = "A Ruby gem for natal astrology chart calculation, powered by Swiss Ephemeris C library with Moshier ephemeris. No external data files needed."
  spec.homepage      = "https://github.com/huangyudi/astro_chart"
  spec.license       = "AGPL-3.0"
  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "ext/**/*.{rb,c,h}", "LICENSE", "astro_chart.gemspec"]
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/astro_chart/extconf.rb"]

  spec.add_dependency "tzinfo", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2"
end
