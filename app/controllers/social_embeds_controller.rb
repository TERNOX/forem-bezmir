# Fork-only. Public liveness endpoint consumed by initializeSocialEmbeds.js: given
# a platform + source id it reports whether the original social post is still live
# or has been deleted, so the front-end can swap a dead widget for its durable
# archive card. Returns the stored status (fast); a stale snapshot triggers a
# background re-check so the next view is accurate.
class SocialEmbedsController < ApplicationController
  def status
    platform = params[:platform].to_s
    source_id = params[:source_id].to_s
    snapshot = SocialPostSnapshot.find_by(platform: platform, source_id: source_id)

    if snapshot&.stale_for_liveness?
      SocialEmbeds::SnapshotWorker.perform_async(
        snapshot.platform, snapshot.source_id, snapshot.source_url, snapshot.at_uri
      )
    end

    expires_in 10.minutes, public: true
    render json: {
      status: snapshot&.source_status || "unknown",
      archived: snapshot&.archived_fallback? || false
    }
  end
end
