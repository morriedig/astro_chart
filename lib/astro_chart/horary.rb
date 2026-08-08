require_relative "ephemeris"
require_relative "zodiac"
require_relative "pure/core"

module AstroChart
  # Horary / traditional condition (卜卦占星). Judges the sky at the moment a
  # question is asked: applying vs separating aspects and when they perfect,
  # the perfection modes that carry or break a matter (translation, collection,
  # prohibition, frustration, refranation), the Sun's affliction of a planet
  # (cazimi / combust / under the beams), and the Moon's condition (void of
  # course, via combusta, speed, next aspect). Plus the classical
  # "considerations before judgment" (radicality) flags.
  #
  # Thresholds follow William Lilly's Christian Astrology (1647) by default,
  # with John Frawley and Bonatti's common variants exposed as keyword args.
  # Everything is signed-speed based, so retrograde is handled throughout.
  module Horary
    Core = Pure::Core

    MAJOR_ANGLES = [0, 60, 90, 120, 180].freeze
    MINOR_ANGLES = [30, 45, 135, 150].freeze
    ANGLE_NAMES = {
      0 => "合相", 30 => "十二分相", 45 => "半四分相", 60 => "六分相",
      90 => "四分相", 120 => "三分相", 135 => "補八分相", 150 => "補十二分相",
      180 => "對分相"
    }.freeze

    # Lilly's whole orbs (moiety = half). The moiety sum of two bodies is the
    # maximum separation-from-exact at which they are held to aspect.
    ORBS = {
      "太陽" => 15.0, "月亮" => 12.0, "水星" => 7.0, "金星" => 7.0,
      "火星" => 7.0, "木星" => 9.0, "土星" => 9.0,
      "天王星" => 5.0, "海王星" => 5.0, "冥王星" => 5.0, "北交點" => 5.0
    }.freeze
    DEFAULT_ORB = 5.0

    # Solar phases (Lilly CA p.113). Cazimi overrides combust overrides beams.
    CAZIMI_ORB = 17.0 / 60.0     # 0°17'; Bonatti variant 0°16'
    COMBUST_ORB = 8.5            # 8°30'; some traditions 8°
    UNDER_BEAMS_ORB = 17.0       # 17°; Frawley-lineage often 15°

    MOON_MEAN_SPEED = 13.1764    # 13°10'35"/day
    VIA_COMBUSTA = (195.0..225.0) # 15° Libra – 15° Scorpio

    STATION_EPS = 1e-6           # |speed| below this ⇒ effectively stationary
    SPEED_EPS = 0.05             # |Δspeed| below this ⇒ applier ambiguous

    # Perfection search: horary cares about the *nearest* future perfection, so
    # bracket-and-bisect a bounded window (robust through stations, unlike
    # Newton). Beyond the horizon the time is left nil ("perfects, but not soon").
    SEARCH_HORIZON = 40.0        # days
    SEARCH_STEP = 0.5            # days; << the gap between adjacent Ptolemaic targets

    # Bodies that receive/ carry aspects (no南交點: it mirrors 北交點).
    POSITION_BODIES = Ephemeris::PLANETS.keys.freeze
    ASPECT_BODIES = (Ephemeris::PLANETS.keys - ["北交點"]).freeze
    TRAD_PLANETS = %w[太陽 月亮 水星 金星 火星 木星 土星].freeze
    MOON_ASPECT_BODIES = %w[太陽 水星 金星 火星 木星 土星].freeze
    SOLAR_BODIES = %w[月亮 水星 金星 火星 木星 土星].freeze

    # ── Public API ──────────────────────────────────────────────────────────

    # Everything the moment shows, for a question cast at jd. Pass the chart's
    # ascendant/cusps to also get the radicality considerations.
    def self.snapshot(jd, minor: false, ascendant: nil, cusps: nil)
      {
        "positions" => positions(jd),
        "aspects" => aspects(jd, minor: minor),
        "solar_phases" => solar_phases(jd).reject { |p| p["phase"] == "free" },
        "moon" => moon_condition(jd),
        "considerations" => considerations(jd, ascendant: ascendant, cusps: cusps)
      }
    end

    # Longitude / sign / speed / retrograde for every body.
    def self.positions(jd)
      POSITION_BODIES.map do |name|
        lon, spd = state(jd, name)
        {
          "planet" => name,
          "zodiac" => Zodiac.sign_name(lon),
          "degree" => (lon % 30.0).round(4),
          "total_degree" => lon.round(4),
          "speed" => spd.round(4),
          "retrograde" => luminary?(name) ? false : spd < 0
        }
      end
    end

    # All in-orb aspects between the aspecting bodies, tightest first, each with
    # motion (applying/separating/stationary), the applier, time to perfection,
    # and partile / out-of-sign flags.
    def self.aspects(jd, minor: false, orbs: ORBS)
      angles = minor ? (MAJOR_ANGLES + MINOR_ANGLES) : MAJOR_ANGLES
      ASPECT_BODIES.combination(2).filter_map do |a, b|
        pair_aspect(jd, a, b, angles, orbs)
      end.sort_by { |x| x["orb"] }
    end

    # Each of the five planets and the Moon relative to the Sun.
    def self.solar_phases(jd, cazimi_orb: CAZIMI_ORB, combust_orb: COMBUST_ORB,
                          under_beams_orb: UNDER_BEAMS_ORB)
      sun_lon, sun_spd = state(jd, "太陽")
      SOLAR_BODIES.map do |name|
        lon, spd = state(jd, name)
        off = Core.norm360(lon - sun_lon)
        off = off - 360.0 if off > 180.0
        d = off.abs
        omega = spd - sun_spd
        phase =
          if d <= cazimi_orb then "cazimi"
          elsif d <= combust_orb then "combust"
          elsif d <= under_beams_orb then "under_beams"
          else "free"
          end
        {
          "planet" => name,
          "distance_from_sun" => d.round(3),
          # Moving toward the Sun (worse) vs emerging from the beams (improving).
          "applying_to_sun" => omega.abs >= STATION_EPS && (off * omega < 0),
          "phase" => phase
        }
      end.sort_by { |p| p["distance_from_sun"] }
    end

    # The Moon's condition: void of course (Lilly: perfects no aspect before it
    # leaves its sign), via combusta, speed, and the next aspect it forms.
    def self.moon_condition(jd, bodies: MOON_ASPECT_BODIES)
      moon_lon, moon_spd = state(jd, "月亮")
      deg_to_egress = 30.0 - (moon_lon % 30.0)
      t_egress = deg_to_egress / moon_spd

      nxt = nil
      bodies.each do |p|
        lp, sp = state(jd, p)
        omega = sp - moon_spd
        next if omega.abs < STATION_EPS
        sep = Core.norm360(lp - moon_lon)
        MAJOR_ANGLES.each do |ang|
          targets = (ang.zero? || ang == 180) ? [ang] : [ang, 360 - ang]
          targets.each do |tau|
            off = ((sep - tau + 180.0) % 360.0) - 180.0
            t = -off / omega
            next unless t > 0
            nxt = { planet: p, ang: ang, off: off.abs, t: t } if nxt.nil? || t < nxt[:t]
          end
        end
      end

      void = nxt.nil? || nxt[:t] > t_egress
      {
        "void_of_course" => void,
        "via_combusta" => VIA_COMBUSTA.cover?(moon_lon % 360.0),
        "speed" => moon_spd.round(4),
        "speed_class" => moon_spd > MOON_MEAN_SPEED ? "fast" : "slow",
        "sign" => Zodiac.sign_name(moon_lon),
        "degrees_to_egress" => deg_to_egress.round(3),
        "next_aspect" => nxt && {
          "planet" => nxt[:planet],
          "aspect_type" => ANGLE_NAMES[nxt[:ang]],
          "degrees_to_exact" => nxt[:off].round(3),
          "perfects_in_days" => nxt[:t].round(3),
          "before_egress" => nxt[:t] <= t_egress
        }
      }
    end

    # How (or whether) the aspect between two significators completes: the
    # direct application plus every perfection mode acting before it.
    def self.perfection(jd, querent, quesited, orbs: ORBS, horizon_days: 90.0)
      direct = pair_aspect(jd, querent, quesited, MAJOR_ANGLES, orbs)
      t_ab = (direct && direct["applying"]) ? direct["perfects_in_days"] : nil
      sq = state(jd, querent)[1]
      sp = state(jd, quesited)[1]
      others = TRAD_PLANETS - [querent, quesited]
      modes = []

      # Refranation: the APPLIER (the body going to the aspect) stations before
      # it perfects. Only the applier can refrain — a station of the receiver may
      # instead hasten perfection — and only a real applying aspect can be broken.
      if t_ab
        appliers = direct["applier"] ? [direct["applier"]] : [querent, quesited]
        appliers.each do |s|
          ts = station_before(jd, s, t_ab)
          next unless ts && ts < t_ab
          modes << { "type" => "refranation", "significator" => s, "perfects_in_days" => ts.round(3) }
        end
      end

      # Prohibition / frustration: a third planet already in orb and applying
      # reaches a significator before the direct aspect perfects. (Traditional
      # by-application reading: a body not yet in orb is not considered.)
      others.each do |p|
        [[querent, "prohibition"], [quesited, "frustration"]].each do |sig, label|
          ap = pair_aspect(jd, p, sig, MAJOR_ANGLES, orbs)
          next unless ap && ap["applying"] && ap["perfects_in_days"] && t_ab
          next unless ap["perfects_in_days"] < t_ab
          modes << {
            "type" => label, "third" => p, "significator" => sig,
            "aspect_type" => ap["aspect_type"], "perfects_in_days" => ap["perfects_in_days"]
          }
        end
      end

      # Translation: a faster planet separates from one, applies to the other.
      others.each do |tr|
        st = state(jd, tr)[1]
        next unless st.abs > sq.abs && st.abs > sp.abs
        a_q = pair_aspect(jd, tr, querent, MAJOR_ANGLES, orbs)
        a_p = pair_aspect(jd, tr, quesited, MAJOR_ANGLES, orbs)
        next unless a_q && a_p
        if a_q["motion"] == "separating" && a_p["applying"]
          modes << translation(tr, querent, quesited, a_p)
        elsif a_p["motion"] == "separating" && a_q["applying"]
          modes << translation(tr, quesited, querent, a_q)
        end
      end

      # Collection: a slower planet both significators apply to.
      others.each do |c|
        sc = state(jd, c)[1]
        next unless sc.abs < sq.abs && sc.abs < sp.abs
        a_q = pair_aspect(jd, querent, c, MAJOR_ANGLES, orbs)
        a_p = pair_aspect(jd, quesited, c, MAJOR_ANGLES, orbs)
        next unless a_q && a_q["applying"] && a_p && a_p["applying"]
        modes << {
          "type" => "collection", "third" => c,
          "perfects_in_days" => [a_q["perfects_in_days"], a_p["perfects_in_days"]].max.round(3)
        }
      end

      {
        "significators" => [querent, quesited],
        "direct_aspect" => t_ab && {
          "aspect_type" => direct["aspect_type"], "perfects_in_days" => t_ab
        },
        "modes" => modes,
        "verdict" => verdict(t_ab, modes)
      }
    end

    # Considerations before judgment (radicality). Ascendant/cusps optional.
    def self.considerations(jd, ascendant: nil, cusps: nil)
      moon_lon = state(jd, "月亮")[0]
      mc = moon_condition(jd)
      out = {
        "moon_void_of_course" => mc["void_of_course"],
        "moon_via_combusta" => mc["via_combusta"],
        "moon_late_degree" => (moon_lon % 30.0) >= 29.0
      }
      if ascendant
        asc = ascendant % 30.0
        out["ascendant_too_early"] = asc < 3.0
        out["ascendant_too_late"] = asc > 27.0
      end
      if cusps && cusps.length == 12
        out["saturn_in_seventh"] = house_of(state(jd, "土星")[0], cusps) == 7
        out["malefic_in_first"] = [state(jd, "土星")[0], state(jd, "火星")[0]]
                                  .any? { |l| house_of(l, cusps) == 1 }
      end
      out
    end

    # ── Internals ───────────────────────────────────────────────────────────

    def self.state(jd, name)
      id = Ephemeris::PLANETS[name]
      [Ephemeris.calc_ut(jd, id), Ephemeris.speed(jd, id)]
    end

    def self.luminary?(name)
      name == "太陽" || name == "月亮"
    end

    # The tightest in-orb aspect between a and b, or nil.
    def self.pair_aspect(jd, a, b, angles, orbs)
      la, sa = state(jd, a)
      lb, sb = state(jd, b)
      sep = Core.norm360(lb - la)

      best = nil
      angles.each do |ang|
        targets = (ang.zero? || ang == 180) ? [ang] : [ang, 360 - ang]
        targets.each do |tau|
          off = ((sep - tau + 180.0) % 360.0) - 180.0
          best = { ang: ang, tau: tau, off: off } if best.nil? || off.abs < best[:off].abs
        end
      end

      moiety = (orbs.fetch(a, DEFAULT_ORB) + orbs.fetch(b, DEFAULT_ORB)) / 2.0
      return nil if best[:off].abs > moiety

      omega = sb - sa
      off = best[:off]
      motion =
        if omega.abs < STATION_EPS then "stationary"
        elsif off * omega < 0 then "applying"
        else "separating"
        end

      # The applier (the body "going to" the aspect) is only meaningful while
      # applying; near-equal speeds leave it ambiguous.
      applier, receiver =
        if motion != "applying" || (sa.abs - sb.abs).abs < SPEED_EPS then [nil, nil]
        elsif sa.abs > sb.abs then [a, b]
        else [b, a]
        end

      {
        "planet" => a, "other" => b,
        "aspect_type" => ANGLE_NAMES[best[:ang]],
        "orb" => off.abs.round(3),
        "motion" => motion,
        "applying" => motion == "applying",
        "applier" => applier, "receiver" => receiver,
        # Only the applier "goes to" the aspect, so applier/perfection are
        # reported for applying aspects only.
        "perfects_in_days" => motion == "applying" ? time_to_perfection(jd, a, b, best[:tau])&.round(3) : nil,
        "partile" => off.abs <= 1.0,
        "out_of_sign" => out_of_sign?(la, lb, best[:ang])
      }
    end

    # Signed distance (deg, (-180,180]) of the a-b separation from target tau at
    # jd; nil past a body's valid ephemeris range.
    def self.signed_off(jd, a, b, tau)
      la = Ephemeris.calc_ut(jd, Ephemeris::PLANETS[a])
      lb = Ephemeris.calc_ut(jd, Ephemeris::PLANETS[b])
      ((Core.norm360(lb - la) - tau + 180.0) % 360.0) - 180.0
    rescue Core::DomainError
      nil
    end

    # Days until the a-b separation next equals tau — the FIRST future crossing
    # of signed_off through zero, found by grid-bracket then bisection. Robust
    # through retrograde stations (no linear-motion assumption). nil if no
    # crossing within SEARCH_HORIZON or at an ephemeris edge.
    def self.time_to_perfection(jd, a, b, tau, horizon: SEARCH_HORIZON, step: SEARCH_STEP)
      prev_t = 0.0
      prev_h = signed_off(jd, a, b, tau)
      return nil if prev_h.nil?
      t = step
      while t <= horizon
        h = signed_off(jd + t, a, b, tau)
        return nil if h.nil?
        # A sign change of the near-target offset brackets a perfection. The
        # |h|<90 guard rejects the ±180 wrap discontinuity far from exact.
        if prev_h != 0 && (prev_h <=> 0) != (h <=> 0) && prev_h.abs < 90.0 && h.abs < 90.0
          lo = prev_t
          hi = t
          hlo = prev_h
          40.times do
            mid = (lo + hi) / 2.0
            hm = signed_off(jd + mid, a, b, tau)
            break if hm.nil?
            return mid if hm.zero?
            (hlo <=> 0) != (hm <=> 0) ? hi = mid : (lo = mid; hlo = hm)
          end
          return (lo + hi) / 2.0
        end
        prev_t = t
        prev_h = h
        t += step
      end
      nil
    end

    # An aspect degrees-valid but sign-invalid (dissociate) — traditionally weak
    # or no aspect. Only meaningful for the sign-multiple (Ptolemaic) angles.
    def self.out_of_sign?(la, lb, ang)
      return false unless (ang % 30).zero?
      sign_a = (la % 360.0).floor / 30
      sign_b = (lb % 360.0).floor / 30
      dist = (sign_b - sign_a) % 12
      expected = ang / 30
      !(dist == expected || dist == (12 - expected) % 12)
    end

    # First station (speed sign change) of body within horizon days, or nil.
    def self.station_before(jd, body, horizon)
      return nil if luminary?(body)
      id = Ephemeris::PLANETS[body]
      prev_t = 0.0
      prev_s = Ephemeris.speed(jd, id)
      t = 1.0
      while t <= horizon
        s = begin
          Ephemeris.speed(jd + t, id)
        rescue Core::DomainError
          return nil
        end
        if prev_s != 0 && (prev_s <=> 0) != (s <=> 0)
          lo = prev_t
          hi = t
          40.times do
            mid = (lo + hi) / 2.0
            sm = Ephemeris.speed(jd + mid, id)
            (sm <=> 0) == (prev_s <=> 0) ? lo = mid : hi = mid
          end
          return (lo + hi) / 2.0
        end
        prev_t = t
        prev_s = s
        t += 1.0
      end
      nil
    end

    def self.translation(third, from, to, applying_leg)
      {
        "type" => "translation", "third" => third,
        "from" => from, "to" => to,
        "perfects_in_days" => applying_leg["perfects_in_days"]
      }
    end

    # The earliest-acting mechanism wins: a direct perfection before any blocker
    # perfects; else the earliest alternate that completes before the blocker;
    # else the block denies it; else nothing forms.
    def self.verdict(t_ab, modes)
      blockers = modes.select { |m| %w[prohibition frustration refranation].include?(m["type"]) }
      alts = modes.select { |m| %w[translation collection].include?(m["type"]) }
      tb = blockers.map { |m| m["perfects_in_days"] }.compact.min
      earliest_alt = alts.min_by { |m| m["perfects_in_days"] || Float::INFINITY }
      ta = earliest_alt && earliest_alt["perfects_in_days"]

      if t_ab && (tb.nil? || t_ab < tb) then "perfects"
      elsif earliest_alt && (tb.nil? || (ta && ta < tb)) then "perfects_via_#{earliest_alt["type"]}"
      elsif tb then "denied"
      else "no_perfection"
      end
    end

    # Which house (1-12) a longitude falls in, given the 12 cusp longitudes.
    def self.house_of(lon, cusps)
      lon %= 360.0
      12.times do |i|
        a = cusps[i] % 360.0
        span = (cusps[(i + 1) % 12] % 360.0 - a) % 360.0
        return i + 1 if span.zero? || (lon - a) % 360.0 < span
      end
      12
    end

    private_class_method :state, :luminary?, :pair_aspect, :signed_off,
                         :time_to_perfection, :out_of_sign?, :station_before,
                         :translation, :verdict, :house_of
  end
end
