require_relative "ephemeris"
require_relative "pure/core"

module AstroChart
  # Planetary hours (行星時) and the day ruler (日主星) — the classical division
  # of the day. The astrological day runs sunrise→sunrise; its daytime (sunrise→
  # sunset) and night (sunset→next sunrise) are each split into twelve unequal
  # "hours". The first hour of the day is ruled by the day ruler (the ruler of
  # the weekday), and the rulers then step through the Chaldean order.
  #
  # Sunrise/sunset are the instants the Sun's centre is 0°50' below the horizon
  # (34' refraction + 16' semidiameter), found by root-finding the Sun's
  # altitude — so this needs a location. Circumpolar days (no sunrise or no
  # sunset within the day) raise DomainError.
  module PlanetaryHours
    Core = Pure::Core
    DEG2RAD = Core::DEG2RAD
    RAD2DEG = Core::RAD2DEG
    SUN_ID = Ephemeris::PLANETS["太陽"]

    HORIZON_ALT = -0.8333 # Sun-centre altitude at sunrise/sunset

    # Chaldean order (slowest → fastest); consecutive hours step through it.
    CHALDEAN = %w[土星 木星 火星 太陽 金星 水星 月亮].freeze
    # Ruler of each weekday, 0 = Sunday … 6 = Saturday.
    DAY_RULERS = %w[太陽 月亮 火星 水星 木星 金星 土星].freeze

    module_function

    # The planetary hour in force at jd_ut for the given place:
    #   { "day_ruler", "hour_ruler", "hour_number" (1-24), "day_or_night",
    #     "hour_start" (jd), "hour_end" (jd) }
    def at(jd_ut, latitude:, longitude:)
      f = frame(jd_ut, latitude, longitude)
      start, finish, base = f[:day] ? [f[:sunrise], f[:sunset], 0] : [f[:sunset], f[:next_sunrise], 12]
      length = (finish - start) / 12.0
      index = ((jd_ut - start) / length).floor.clamp(0, 11)
      number = base + index + 1
      ruler = hour_ruler(f[:day_ruler], number)
      {
        "day_ruler" => f[:day_ruler],
        "hour_ruler" => ruler,
        "hour_number" => number,
        "day_or_night" => f[:day] ? "day" : "night",
        "hour_start" => start + index * length,
        "hour_end" => start + (index + 1) * length,
      }
    end

    # All 24 hours of the astrological day containing jd_ut, in order.
    def table(jd_ut, latitude:, longitude:)
      f = frame(jd_ut, latitude, longitude)
      day_len = (f[:sunset] - f[:sunrise]) / 12.0
      night_len = (f[:next_sunrise] - f[:sunset]) / 12.0
      (1..24).map do |number|
        if number <= 12
          start = f[:sunrise] + (number - 1) * day_len
          finish = start + day_len
        else
          start = f[:sunset] + (number - 13) * night_len
          finish = start + night_len
        end
        {
          "hour_number" => number,
          "ruler" => hour_ruler(f[:day_ruler], number),
          "day_or_night" => number <= 12 ? "day" : "night",
          "hour_start" => start,
          "hour_end" => finish,
        }
      end
    end

    # Just the ruler of the weekday at this place/time (sunrise-based).
    def day_ruler(jd_ut, latitude:, longitude:)
      frame(jd_ut, latitude, longitude)[:day_ruler]
    end

    # ── internals ─────────────────────────────────────────────────────────

    def hour_ruler(day_ruler, number)
      CHALDEAN[(CHALDEAN.index(day_ruler) + number - 1) % 7]
    end

    # The astrological day around jd_ut: which sunrise began it, its sunset, the
    # next sunrise, whether jd_ut is in daytime, and the day ruler.
    def frame(jd_ut, lat, lon)
      prev_rise = previous_event(jd_ut, lat, lon, :rising)
      prev_set = previous_event(jd_ut, lat, lon, :setting)

      if prev_rise > prev_set
        # Last event was a sunrise ⇒ daytime.
        sunrise = prev_rise
        sunset = next_event(prev_rise, lat, lon, :setting)
        day = true
      else
        # Last event was a sunset ⇒ night; the day began at the sunrise before it.
        sunset = prev_set
        sunrise = previous_event(prev_set, lat, lon, :rising)
        day = false
      end
      next_sunrise = next_event(sunset, lat, lon, :rising)

      {
        day: day, sunrise: sunrise, sunset: sunset, next_sunrise: next_sunrise,
        day_ruler: DAY_RULERS[weekday(sunrise, lon)],
      }
    end

    # Sun altitude (deg) at jd minus the horizon target; its sign flips at
    # sunrise/sunset.
    def altitude_offset(jd, lat, lon)
      lam_deg, beta_deg = Ephemeris.ecliptic_latlon(jd, SUN_ID)
      eps = Core.true_obliquity(Core.jd_tt(jd)) * DEG2RAD
      lam = lam_deg * DEG2RAD
      beta = beta_deg * DEG2RAD
      ra = Math.atan2(Math.sin(lam) * Math.cos(eps) - Math.tan(beta) * Math.sin(eps), Math.cos(lam)) * RAD2DEG
      dec = Math.asin(Math.sin(beta) * Math.cos(eps) + Math.cos(beta) * Math.sin(eps) * Math.sin(lam))
      ha = (Core.apparent_sidereal_deg(jd) + lon - ra) * DEG2RAD
      alt = Math.asin(Math.sin(lat * DEG2RAD) * Math.sin(dec) +
                      Math.cos(lat * DEG2RAD) * Math.cos(dec) * Math.cos(ha)) * RAD2DEG
      alt - HORIZON_ALT
    end

    def next_event(jd, lat, lon, mode)
      scan(jd, jd + 1.6, lat, lon, mode) || circumpolar!(mode)
    end

    def previous_event(jd, lat, lon, mode)
      scan(jd - 1.6, jd, lat, lon, mode, last: true) || circumpolar!(mode)
    end

    def circumpolar!(mode)
      raise Core::DomainError,
            "no sun#{mode == :rising ? 'rise' : 'set'} within a day (circumpolar latitude)"
    end

    # Bracket the altitude-offset sign changes over [a, b] at 10-minute steps and
    # bisect. :rising = crossing upward (− → +); :setting = downward.
    def scan(a, b, lat, lon, mode, last: false)
      step = 1.0 / 144.0
      want_up = mode == :rising
      found = nil
      t0 = a
      f0 = altitude_offset(t0, lat, lon)
      t = a + step
      while t <= b
        f1 = altitude_offset(t, lat, lon)
        if f0 != 0 && (f0 <=> 0) != (f1 <=> 0) && ((f1 > f0) == want_up)
          root = bisect(t0, t, lat, lon)
          return root unless last

          found = root
        end
        t0 = t
        f0 = f1
        t += step
      end
      found
    end

    def bisect(a, b, lat, lon)
      fa = altitude_offset(a, lat, lon)
      40.times do
        break if (b - a) < 1.0e-6

        mid = (a + b) / 2.0
        fm = altitude_offset(mid, lat, lon)
        return mid if fm.zero?

        (fa <=> 0) != (fm <=> 0) ? b = mid : (a = mid; fa = fm)
      end
      (a + b) / 2.0
    end

    # Weekday of the local civil date at a sunrise (longitude gives the local
    # offset). 0 = Sunday … 6 = Saturday.
    def weekday(sunrise_jd, lon)
      ((sunrise_jd + lon / 360.0 + 1.5).floor % 7)
    end

    private_class_method :hour_ruler, :frame, :altitude_offset, :next_event,
                         :previous_event, :circumpolar!, :scan, :bisect, :weekday
  end
end
