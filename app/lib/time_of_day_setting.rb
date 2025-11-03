# frozen_string_literal: true

class TimeOfDaySetting
  TIME_PATTERN = /\A\s*([01]?\d|2[0-3]):([0-5]\d)\s*\z/.freeze

  class << self
    def matches?(time, configured_value)
      hours, minutes = extract_components(configured_value)
      return false if hours.nil? || minutes.nil?

      utc_time = time.utc
      utc_time.hour == hours && utc_time.min == minutes
    end

    def normalize(value)
      hours, minutes = extract_components(value)
      return nil if hours.nil? || minutes.nil?

      format("%02d:%02d", hours, minutes)
    end

    def extract_components(value)
      return [0, 0] if value.nil?

      match = TIME_PATTERN.match(value.to_s)
      return [nil, nil] if match.nil?

      [match[1].to_i, match[2].to_i]
    end
  end
end
