module SocialAutopost
  # Posting windows per weekday in Kyiv time, e.g. "19:00-21:30" or
  # "13:00-16:00, 18:00-22:00". An empty day means no posting that day.
  class Schedule
    WINDOW_PATTERN = /\A(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})\z/

    Window = Struct.new(:start_minute, :end_minute) do
      def cover?(minute)
        minute >= start_minute && minute < end_minute
      end
    end

    def self.time_zone
      Articles::TopArticles::DigestSchedule.time_zone
    end

    # @return [Array<Window>] or raises ArgumentError for a malformed value.
    def self.parse(value)
      value.to_s.split(/[,;\n]+/).map(&:strip).compact_blank.map do |segment|
        match = WINDOW_PATTERN.match(segment)
        raise ArgumentError, "Invalid posting window \"#{segment}\". Use HH:MM-HH:MM." unless match

        start_minute = (match[1].to_i * 60) + match[2].to_i
        end_minute = (match[3].to_i * 60) + match[4].to_i
        if match[2].to_i > 59 || match[4].to_i > 59 || end_minute > 24 * 60 || start_minute >= end_minute
          raise ArgumentError, "Invalid posting window \"#{segment}\". The end must come after the start."
        end

        Window.new(start_minute, end_minute)
      end
    end

    def initialize(settings = Settings::SocialAutopost)
      @windows_by_day = Settings::SocialAutopost::WEEKDAYS.index_with do |day|
        self.class.parse(settings.public_send(:"schedule_#{day}"))
      rescue ArgumentError
        []
      end
    end

    def open_at?(time)
      local = time.in_time_zone(self.class.time_zone)
      minute = (local.hour * 60) + local.min
      windows_for(local).any? { |window| window.cover?(minute) }
    end

    # The first moment at or after `from` that falls inside a window, or nil
    # when no day has a window.
    def next_open_at(from)
      local = from.in_time_zone(self.class.time_zone)
      return from if open_at?(from)

      8.times do |offset|
        day = (local + offset.days).beginning_of_day
        windows_for(day).sort_by(&:start_minute).each do |window|
          candidate = day + window.start_minute.minutes
          return candidate if candidate >= local
        end
      end
      nil
    end

    def beginning_of_local_day(time)
      time.in_time_zone(self.class.time_zone).beginning_of_day
    end

    private

    def windows_for(local_time)
      @windows_by_day.fetch(local_time.strftime("%A").downcase, [])
    end
  end
end
