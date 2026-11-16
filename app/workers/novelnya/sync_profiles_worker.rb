module Novelnya
  # Fork-only: refreshes the cached list of Новельня profiles (see
  # Novelnya::Profiles) and purges the profile pages whose block changed, so
  # a link appears or goes away without waiting for the edge cache to expire.
  class SyncProfilesWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: false, lock: :until_executed, on_conflict: :log

    def perform
      changed = Novelnya::Profiles.refresh!
      return if changed.blank?

      User.where(id: changed).find_each { |user| EdgeCache::BustUser.call(user) }
    end
  end
end
