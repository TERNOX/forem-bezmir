# Fork-only. Public liveness endpoint consumed by initializeSocialEmbeds.js: given
# a platform + source id it reports whether the original social post is still live
# or has been deleted, so the front-end can swap a dead widget for its durable
# archive card.
#
# We only ever do work for embeds we've actually captured (a snapshot exists and is
# renderable); for those we run a REAL, short-cached liveness check so a post
# deleted moments ago is detected on the next page load — not hours later when the
# scheduled refresh worker happens to run.
class SocialEmbedsController < ApplicationController
  LIVENESS_CACHE_TTL = 10.minutes

  def status
    platform = params[:platform].to_s
    source_id = params[:source_id].to_s
    snapshot = SocialPostSnapshot.find_by(platform: platform, source_id: source_id)

    # No durable copy to fall back to -> nothing for the front-end to do, and we
    # deliberately avoid any external call for unknown embeds.
    unless snapshot&.renderable?
      return render json: { status: snapshot&.source_status || "unknown", archived: false }
    end

    current = live_status(snapshot)
    render json: { status: current, archived: current == "deleted" }
  end

  private

  # Real liveness, cached briefly per embed to bound external calls.
  def live_status(snapshot)
    Rails.cache.fetch(cache_key(snapshot), expires_in: LIVENESS_CACHE_TTL) do
      SocialEmbeds::Snapshotter.refresh(snapshot).source_status
    end
  rescue StandardError => e
    Rails.logger.warn("SocialEmbeds status live check failed for ##{snapshot.id}: #{e.class}: #{e.message}")
    snapshot.source_status
  end

  def cache_key(snapshot)
    "social_embed:liveness:#{snapshot.platform}:#{snapshot.source_id}"
  end
end
