# frozen_string_literal: true

module Articles
  class TopArticlesDigestWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 10

    def perform(run_time = nil)
      reference_time = parse_reference_time(run_time)
      return unless publication_window?(reference_time)

      Articles::TopArticles::DigestPublisher.new(reference_time: reference_time).call
    end

    private

    def parse_reference_time(run_time)
      case run_time
      when nil
        Time.zone.now
      when Time
        run_time.in_time_zone
      else
        Time.zone.parse(run_time.to_s)
      end
    rescue ArgumentError
      Time.zone.now
    end

    def publication_window?(reference_time)
      TimeOfDaySetting.matches?(reference_time, Settings::General.top_articles_digest_publish_time)
    end
  end
end
