module SocialAutopost
  # Fork-only: runs the Telegram autoposting loop (see SocialAutopost::Ticker).
  class TickWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: false, lock: :until_executed, on_conflict: :log

    def perform
      SocialAutopost::Ticker.call
    end
  end
end
