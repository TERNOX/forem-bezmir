namespace :cache do
  desc "Enqueue BustCachePathWorker"
  task enqueue_path_bust_workers: :environment do
    # Trigger cache purges for globally-cached endpoints that could have changed
    [30, 180, 600].each do |n|
      begin
        BustCachePathWorker.set(queue: :high_priority).perform_in(n.seconds, "/")
        BustCachePathWorker.set(queue: :high_priority).perform_in(n.seconds, "/onboarding")
      rescue StandardError => e
        if defined?(Redis::BaseError) && e.is_a?(Redis::BaseError)
          Rails.logger.warn("Skipping cache bust enqueue due to Redis error: #{e.class}")
          break
        else
          raise
        end
      end
    end
  end

  desc "Clear application cache"
  task clear_app_cache: :environment do
    raise "Attempting to clear Rails cache in production" if Rails.env.production?

    Rails.cache.clear
  end
end
