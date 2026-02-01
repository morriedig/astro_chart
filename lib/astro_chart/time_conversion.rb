require "tzinfo"

module AstroChart
  module TimeConversion
    # Convert a local date/time + timezone to Julian Day.
    #
    # birth_date: "YYYY-MM-DD"
    # birth_time: "HH:MM"
    # timezone:   IANA timezone string, e.g. "Asia/Taipei"
    def self.to_julian_day(birth_date, birth_time, timezone)
      tz = TZInfo::Timezone.get(timezone)

      parts = birth_date.split("-").map(&:to_i)
      year, month, day = parts

      time_parts = birth_time.split(":").map(&:to_i)
      hour, minute = time_parts

      # Build local time and convert to UTC
      local_time = Time.new(year, month, day, hour, minute, 0, tz.observed_utc_offset)

      # TZInfo gives us the proper UTC offset; convert to UTC
      utc_time = tz.local_to_utc(Time.new(year, month, day, hour, minute, 0))

      ut_hour = utc_time.hour + utc_time.min / 60.0

      Ephemeris.julday(utc_time.year, utc_time.month, utc_time.day, ut_hour)
    end
  end
end
