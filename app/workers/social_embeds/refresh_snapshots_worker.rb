module SocialEmbeds
  # Fork-only. Periodically re-checks captured social-post snapshots so that a post
  # deleted AFTER an article was published gets flipped to "deleted" (which makes
  # the front-end show the durable archive card). Already-deleted snapshots are
  # skipped — once a source is gone it stays gone.
  class RefreshSnapshotsWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, lock: :until_executing

    BATCH_SIZE = 200

    def perform
      # Order matches index_social_post_snapshots_on_checked_at_active (checked_at
      # ASC, NULLS LAST by default) so the scan can be read straight off the index.
      snapshots = SocialPostSnapshot
        .where.not(source_status: :deleted)
        .where("checked_at IS NULL OR checked_at < ?", SocialPostSnapshot::LIVENESS_TTL.ago)
        .order(Arel.sql("checked_at ASC NULLS LAST"))
        .limit(BATCH_SIZE)

      snapshots.each do |snapshot|
        SocialEmbeds::Snapshotter.refresh(snapshot)
      rescue StandardError => e
        Rails.logger.warn(
          "SocialEmbeds::RefreshSnapshotsWorker failed for ##{snapshot.id}: #{e.class}: #{e.message}",
        )
      end
    end
  end
end
