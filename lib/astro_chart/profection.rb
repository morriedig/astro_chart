require "date"
require_relative "zodiac"
require_relative "dignities"

module AstroChart
  # Annual profection (小限法) — the traditional time-lord technique where each
  # completed year of life advances the point of emphasis by one whole sign
  # from the ascendant. Age 0 activates the 1st house (the ASC sign), age 1 the
  # 2nd, and so on, cycling every 12 years. The traditional ruler of the
  # profected sign is the Lord of the Year (年主星), the year's principal
  # significator.
  #
  # Pure arithmetic on the ascendant longitude and an age in whole years.
  module Profection
    module_function

    # ascendant: ecliptic longitude of the ASC (degrees, 0-360)
    # age:        completed years of life (integer ≥ 0)
    #
    # Returns:
    #   { "age" => 36, "profected_house" => 1, "profected_sign" => "牡羊座",
    #     "year_lord" => "火星" }
    def annual(ascendant, age)
      raise ArgumentError, "age must be a non-negative integer" if age.nil? || age < 0

      asc_sign_index = (ascendant % 360).floor / 30
      steps = age % 12
      sign = Zodiac::SIGNS[(asc_sign_index + steps) % 12]

      {
        "age"             => age,
        "profected_house" => steps + 1,
        "profected_sign"  => sign,
        "year_lord"       => Dignities::DOMICILE[sign],
      }
    end

    # Convenience: derive the age (completed years) from birth and target dates
    # (each a "YYYY-MM-DD" string or Date) and profect.
    def at(ascendant, birth_date, target_date)
      annual(ascendant, completed_years(to_date(birth_date), to_date(target_date)))
    end

    # Whole years elapsed from birth to target (the person's age).
    def completed_years(birth, target)
      years = target.year - birth.year
      had_birthday = (target.month > birth.month) ||
                     (target.month == birth.month && target.day >= birth.day)
      had_birthday ? years : years - 1
    end

    def to_date(value)
      value.is_a?(Date) ? value : Date.parse(value)
    end
  end
end
