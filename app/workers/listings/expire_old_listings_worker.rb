module Listings
  # Compatibility for jobs enqueued before Listings was retired. Keep this class
  # loadable so existing queued/retrying jobs can finish without touching listings.
  class ExpireOldListingsWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: 5

    def perform
      # Older cron entries default to source "dynamic", so removing them from
      # schedule.yml does not remove them from Redis. Stop that producer as well.
      cron_jobs = Sidekiq::Cron::Job.all
      cron_jobs.each do |job|
        job.destroy if job.klass == self.class.name
      end
    end
  end
end
