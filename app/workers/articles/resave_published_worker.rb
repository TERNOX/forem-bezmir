module Articles
  class ResavePublishedWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: 10, lock: :until_executing

    def perform
      Article.published.find_each(&:save)
    end
  end
end
