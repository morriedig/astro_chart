require "mkmf"

# Swiss Ephemeris source files to compile alongside our extension
$srcs = Dir.glob("#{$srcdir}/*.c").map { |f| File.basename(f) }

$CFLAGS << " -DNO_SWE_GLP"

create_makefile("astro_chart/astro_chart_ext")
