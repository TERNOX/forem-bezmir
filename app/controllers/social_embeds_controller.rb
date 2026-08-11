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

    # Deletion is terminal: once archived, keep serving that from storage instead
    # of re-hitting the platform API every cache cycle for a dead post.
    return render(json: archived_payload(snapshot)) if snapshot.deleted?

    current = live_status(snapshot)
    return render(json: archived_payload(snapshot)) if current == "deleted"

    render json: { status: current, archived: false }
  end

  private

  # The front-end injects `html` when the article's baked markup lacks an archive
  # card (capture failed at publish time) — it only asks for it in that case, so
  # we skip rendering the partial otherwise.
  def archived_payload(snapshot)
    payload = { status: "deleted", archived: true }
    if params[:include_html].present?
      payload[:html] = render_to_string(partial: "liquids/social_embed_archive",
                                        locals: { snapshot: snapshot }, formats: [:html], layout: false)
    end
    payload
  end

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
