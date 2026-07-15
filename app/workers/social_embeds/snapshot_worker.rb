module SocialEmbeds
  # Fork-only. Captures or refreshes a single social-post snapshot off the request
  # path (used for lazy refresh triggered by the liveness endpoint).
  class SnapshotWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, lock: :until_executing, retry: 5

    def perform(platform, source_id, source_url, at_uri = nil)
      snapshot = SocialPostSnapshot.find_by(platform: platform, source_id: source_id)

      if snapshot
        SocialEmbeds::Snapshotter.refresh(snapshot)
      else
        SocialEmbeds::Snapshotter.call(
          platform: platform, source_id: source_id, source_url: source_url, at_uri: at_uri,
        )
      end
    end
  end
end
