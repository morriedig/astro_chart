#include <ruby.h>
#include "swephexp.h"

static VALUE mAstroChart;
static VALUE mExt;

/*
 * AstroChart::Ext.julday(year, month, day, hour) -> Float
 *
 * Convert a date/time to Julian Day number using Gregorian calendar.
 */
static VALUE rb_julday(VALUE self, VALUE year, VALUE month, VALUE day, VALUE hour) {
    int y = NUM2INT(year);
    int m = NUM2INT(month);
    int d = NUM2INT(day);
    double h = NUM2DBL(hour);

    double jd = swe_julday(y, m, d, h, SE_GREG_CAL);
    return DBL2NUM(jd);
}

/*
 * AstroChart::Ext.calc_ut(jd, planet_id) -> Float
 *
 * Calculate planet ecliptic longitude using Moshier ephemeris.
 * Returns the longitude in degrees (0-360).
 */
static VALUE rb_calc_ut(VALUE self, VALUE jd, VALUE planet_id) {
    double tjd = NUM2DBL(jd);
    int ipl = NUM2INT(planet_id);
    double xx[6];
    char serr[256];

    int32 ret = swe_calc_ut(tjd, ipl, SEFLG_MOSEPH, xx, serr);
    if (ret < 0) {
        rb_raise(rb_eRuntimeError, "swe_calc_ut failed: %s", serr);
    }

    return DBL2NUM(xx[0]); /* ecliptic longitude */
}

/*
 * AstroChart::Ext.houses(jd, latitude, longitude, system) -> Hash
 *
 * Calculate house cusps and ascendant/MC.
 * system: ASCII code for house system (e.g. 'P' = 80 for Placidus)
 *
 * Returns a Hash with:
 *   "cusps"     => Array of 12 house cusp degrees
 *   "ascendant" => Ascendant degree
 *   "mc"        => MC degree
 */
static VALUE rb_houses(VALUE self, VALUE jd, VALUE lat, VALUE lon, VALUE hsys) {
    double tjd = NUM2DBL(jd);
    double geolat = NUM2DBL(lat);
    double geolon = NUM2DBL(lon);
    int system = NUM2INT(hsys);

    double cusps[13];  /* cusps[0] unused, cusps[1..12] */
    double ascmc[10];

    swe_houses(tjd, geolat, geolon, system, cusps, ascmc);

    VALUE result = rb_hash_new();
    VALUE cusps_ary = rb_ary_new_capa(12);

    int i;
    for (i = 1; i <= 12; i++) {
        rb_ary_push(cusps_ary, DBL2NUM(cusps[i]));
    }

    rb_hash_aset(result, rb_str_new_cstr("cusps"), cusps_ary);
    rb_hash_aset(result, rb_str_new_cstr("ascendant"), DBL2NUM(ascmc[0]));
    rb_hash_aset(result, rb_str_new_cstr("mc"), DBL2NUM(ascmc[1]));

    return result;
}

void Init_astro_chart_ext(void) {
    mAstroChart = rb_define_module("AstroChart");
    mExt = rb_define_module_under(mAstroChart, "Ext");

    rb_define_module_function(mExt, "julday", rb_julday, 4);
    rb_define_module_function(mExt, "calc_ut", rb_calc_ut, 2);
    rb_define_module_function(mExt, "houses", rb_houses, 4);

    /* Planet ID constants */
    rb_define_const(mExt, "SUN", INT2NUM(SE_SUN));
    rb_define_const(mExt, "MOON", INT2NUM(SE_MOON));
    rb_define_const(mExt, "MERCURY", INT2NUM(SE_MERCURY));
    rb_define_const(mExt, "VENUS", INT2NUM(SE_VENUS));
    rb_define_const(mExt, "MARS", INT2NUM(SE_MARS));
    rb_define_const(mExt, "JUPITER", INT2NUM(SE_JUPITER));
    rb_define_const(mExt, "SATURN", INT2NUM(SE_SATURN));
    rb_define_const(mExt, "URANUS", INT2NUM(SE_URANUS));
    rb_define_const(mExt, "NEPTUNE", INT2NUM(SE_NEPTUNE));
    rb_define_const(mExt, "PLUTO", INT2NUM(SE_PLUTO));
    rb_define_const(mExt, "TRUE_NODE", INT2NUM(SE_TRUE_NODE));
}
