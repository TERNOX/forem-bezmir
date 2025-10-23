# frozen_string_literal: true

module Articles
  class TopArticlesDigestWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 10

    def perform(run_time = nil)
      Articles::TopArticles::DigestPublisher.new(reference_time: run_time).call
    end
  end
end
