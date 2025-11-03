# frozen_string_literal: true

module Articles
  module TopArticles
    class DigestSchedule
      MAX_ATTEMPTS = 400

      def initialize(settings: Settings::General, reference_time: Time.zone.now)
        @settings = settings
        @reference_time = reference_time
      end

      def next_run_at
        return @next_run_at if defined?(@next_run_at)

        @next_run_at = begin
          candidate = initial_candidate_utc
          attempts = 0

          while candidate && attempts < MAX_ATTEMPTS
            local_candidate = candidate.in_time_zone(Time.zone)
            return local_candidate if due_for?(local_candidate)

            candidate += step_size
            attempts += 1
          end

          nil
        end
      end

      private

      attr_reader :settings, :reference_time

      def publication_time_components
        @publication_time_components ||= begin
          hours, minutes = TimeOfDaySetting.extract_components(settings.top_articles_digest_publish_time)
          return if hours.nil? || minutes.nil?

          [hours, minutes]
        end
      end

      def initial_candidate_utc
        hours, minutes = publication_time_components
        return if hours.nil? || minutes.nil?

        utc_now = reference_time.utc
        candidate = Time.utc(utc_now.year, utc_now.month, utc_now.day, hours, minutes)

        if candidate.in_time_zone(Time.zone) <= reference_time
          candidate += step_size
        end

        candidate
      end

      def step_size
        case settings.top_articles_digest_frequency.to_s
        when "daily"
          1.day
        when "monthly"
          1.day
        else
          1.day
        end
      end

      def due_for?(local_time)
        return false unless local_time

        publisher = Articles::TopArticles::DigestPublisher.new(reference_time: local_time)
        publisher.send(:publication_due?)
      end
    end
  end
end
