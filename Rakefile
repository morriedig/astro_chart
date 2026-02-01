require "rake/extensiontask"
require "rspec/core/rake_task"

Rake::ExtensionTask.new("astro_chart_ext") do |ext|
  ext.lib_dir = "lib/astro_chart"
  ext.ext_dir = "ext/astro_chart"
end

RSpec::Core::RakeTask.new(:spec)

task default: [:compile, :spec]
