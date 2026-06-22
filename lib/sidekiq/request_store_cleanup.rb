module Sidekiq
  # Resets RequestStore around every Sidekiq job.
  #
  # RequestStore is per-thread storage that is meant to live for a single unit of
  # work (a web request, or here a job). Sidekiq does NOT clear it between jobs,
  # so without this middleware a worker thread keeps whatever it memoized in
  # RequestStore for the life of the process.
  #
  # This matters because Settings::Base#all_settings memoizes the settings hash as
  # `RequestStore[cache_key] ||= Rails.cache.fetch(...)`. When one job writes a
  # setting it calls `clear_cache`, which only clears the CURRENT thread's
  # RequestStore (plus Rails.cache) — other worker threads keep a stale copy and
  # the `||=` never re-reads. That let the hourly top-articles digest worker see a
  # stale `top_articles_digest_next_run_at` / `last_period_identifier` and publish
  # the digest multiple times in a row (e.g. 20:00, 21:00, 22:00).
  #
  # Defined under Sidekiq to match the file path lib/sidekiq/request_store_cleanup.rb.
  class RequestStoreCleanup
    def call(_worker, _job, _queue)
      RequestStore.clear!
      RequestStore.begin!
      yield
    ensure
      RequestStore.end!
      RequestStore.clear!
    end
  end
end
