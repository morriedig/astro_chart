require_relative "ephemeris"
require_relative "aspects"
require_relative "zodiac"
require_relative "synastry"
require_relative "solar_return"

module AstroChart
  # Transit timing (行運精確時點): the exact UTC instants, within a date range,
  # when a transiting body forms an exact aspect to a natal point.
  #
  # Where Transits.against is a single snapshot ("what aspects hold right
  # now?"), this answers the question people actually ask — "*when* does
  # transiting 土星 exactly square my natal 太陽?".
  #
  #   natal  = AstroChart::Chart.new(...).generate
  #   events = AstroChart::TransitTiming.events(natal, "2026-01-01", "2026-12-31")
  #   events.first
  #   #=> { "transit_planet" => "土星", "natal_planet" => "太陽",
  #   #     "aspect_type" => "四分相", "jd" => 2461...,
  #   #     "time_utc" => "2026-03-14T07:22:10Z", "transit_zodiac" => "牡羊座",
  #   #     "retrograde" => false }
  #
  # Method: each transiting body's longitude is sampled across the range at
  # `step_days`; for every natal point and aspect angle the signed separation
  # is bracketed where it crosses exactness, then refined by bisection (robust
  # through retrograde stations, unlike a pure Newton step). A step where the
  # body moves < 90° guarantees no aliasing — 1 day is safe for all bodies
  # (the Moon moves ~13°/day).
  module TransitTiming
    # Transiting bodies considered (12-body set minus 南交點, mirroring
    # Synastry/Transits — a south-node hit merely mirrors a north-node one).
    BODIES = Synastry::BODIES

    # Major aspect angles. Each non-zero, non-opposition aspect is exact at two
    # signed separations (applying from either side); 合相/對分相 have one.
    MAJOR = { "合相" => 0, "六分相" => 60, "四分相" => 90, "三分相" => 120, "對分相" => 180 }.freeze
    MINOR = { "十二分相" => 30, "半四分相" => 45, "補八分相" => 135, "補十二分相" => 150 }.freeze

    CONVERGENCE_DAYS = 1e-6 # ~0.1 second of clock time
    MAX_BISECT = 60

    # natal_chart: a Chart#generate result hash.
    # start_date / end_date: "YYYY-MM-DD" (interpreted at 00:00 UT).
    # minor: also time the minor aspects (30/45/135/150).
    # step_days: sampling stride (default 1.0 — safe for every body).
    # bodies: restrict transiting bodies (default all BODIES; e.g. drop "月亮"
    #   to avoid the Moon's ~monthly hits flooding the list).
    #
    # Returns an Array of event hashes sorted by time (jd ascending).
    def self.events(natal_chart, start_date, end_date, minor: false,
                    step_days: 1.0, bodies: nil)
      natal = Synastry.positions_from_chart(natal_chart)
      moving = (bodies || BODIES).select { |b| Ephemeris::PLANETS.key?(b) }
      targets = signed_targets(minor)

      jd_start = date_to_jd(start_date)
      jd_end   = date_to_jd(end_date)

      events = []
      moving.each do |body|
        id = Ephemeris::PLANETS[body]
        # Sample this body's longitude ONCE across the grid, then reuse the
        # cached samples for every natal point × aspect target (calc_ut is the
        # cost; the scan phase does zero extra ephemeris calls, only bisection
        # refinement recomputes).
        grid = sample_grid(id, jd_start, jd_end, step_days)

        natal.each do |n_name, n_pos|
          targets.each do |aspect_type, sep|
            scan_grid(grid, n_pos, sep).each do |jd0, h0, jd1, h1|
              jd = bisect(id, n_pos, sep, jd0, h0, jd1, h1)
              events << build_event(body, id, n_name, aspect_type, jd)
            end
          end
        end
      end

      dedupe(events).sort_by { |e| e["jd"] }
    end

    # [[jd, lon], ...] samples of one body from jd_start to jd_end (inclusive).
    def self.sample_grid(id, jd_start, jd_end, step)
      grid = []
      jd = jd_start
      loop do
        jd = jd_end if jd > jd_end
        grid << [jd, Ephemeris.calc_ut(jd, id)]
        break if jd >= jd_end

        jd += step
      end
      grid
    end

    # Brackets where the signed separation crosses exactness, from cached
    # longitudes. Returns [[jd0, h0, jd1, h1], ...] for bisection.
    def self.scan_grid(grid, natal_pos, sep)
      brackets = []
      grid.each_cons(2) do |(jd0, l0), (jd1, l1)|
        h0 = SolarReturn.angle_delta(l0 - natal_pos - sep)
        h1 = SolarReturn.angle_delta(l1 - natal_pos - sep)
        # A sign change with both endpoints near the target (|h| < 90°) is a
        # real crossing; the |h| guard rejects the ±180° wrap discontinuity.
        next unless h0 != 0 && (h0 <=> 0) != (h1 <=> 0) && h0.abs < 90 && h1.abs < 90

        brackets << [jd0, h0, jd1, h1]
      end
      brackets
    end

    # Signed separations at which each aspect is exact. 合相 (0) and 對分相
    # (180) have a single point; the rest have ±angle.
    def self.signed_targets(minor)
      table = minor ? MAJOR.merge(MINOR) : MAJOR
      table.flat_map do |name, angle|
        if angle.zero? || angle == 180
          [[name, angle]]
        else
          [[name, angle], [name, -angle]]
        end
      end
    end

    def self.bisect(id, natal_pos, sep, a, ha, b, _hb)
      MAX_BISECT.times do
        break if (b - a) < CONVERGENCE_DAYS

        mid = (a + b) / 2.0
        hm = separation(id, mid, natal_pos, sep)
        if hm == 0
          return mid
        elsif (ha <=> 0) != (hm <=> 0)
          b = mid
        else
          a = mid
          ha = hm
        end
      end
      (a + b) / 2.0
    end

    # Signed distance (deg, [-180,180)) from exactness of this aspect.
    def self.separation(id, jd, natal_pos, sep)
      SolarReturn.angle_delta(Ephemeris.calc_ut(jd, id) - natal_pos - sep)
    end

    def self.build_event(body, id, natal_name, aspect_type, jd)
      lon = Ephemeris.calc_ut(jd, id)
      {
        "transit_planet" => body,
        "natal_planet"   => natal_name,
        "aspect_type"    => aspect_type,
        "jd"             => jd,
        "time_utc"       => SolarReturn.jd_to_utc_iso8601(jd),
        "transit_zodiac" => Zodiac.sign_name(lon),
        "retrograde"     => never_retrograde?(body) ? false : Ephemeris.retrograde?(jd, id),
      }
    end

    def self.never_retrograde?(body)
      body == "太陽" || body == "月亮"
    end

    # Two roots for the same contact found at adjacent brackets (a root landing
    # on a sample boundary) collapse to one.
    def self.dedupe(events)
      events
        .group_by { |e| [e["transit_planet"], e["natal_planet"], e["aspect_type"]] }
        .flat_map do |_key, group|
          group.sort_by { |e| e["jd"] }.chunk_while { |a, b| (b["jd"] - a["jd"]) < 1e-3 }
               .map(&:first)
        end
    end

    def self.date_to_jd(date)
      y, m, d = date.split("-").map(&:to_i)
      raise ArgumentError, "invalid date: #{date.inspect}" if y.nil? || m.nil? || d.nil?

      Ephemeris.julday(y, m, d, 0.0)
    end

    private_class_method :signed_targets, :sample_grid, :scan_grid, :bisect,
                         :separation, :build_event, :never_retrograde?,
                         :dedupe, :date_to_jd
  end
end
