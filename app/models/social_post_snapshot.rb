# Fork-only feature. A durable, self-hosted copy of an embedded social post
# (Twitter/X or Bluesky) captured at article-save time so the quote survives even
# after the original post/account is deleted. Populated by SocialEmbeds::Snapshotter
# and re-checked by SocialEmbeds::RefreshSnapshotsWorker.
class SocialPostSnapshot < ApplicationRecord
  # unknown: not yet fetched; live: source confirmed present; deleted: source gone
  # (404); unavailable: source could not be fetched (rate-limited/API down) but is
  # not confirmed deleted.
  enum :source_status, { unknown: 0, live: 1, deleted: 2, unavailable: 3 }, default: :unknown

  PLATFORMS = %w[twitter bluesky].freeze

  # How long a liveness check is trusted before the status endpoint triggers a
  # background re-check.
  LIVENESS_TTL = 6.hours

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :source_id, presence: true, uniqueness: { scope: :platform }
  validates :source_url, presence: true

  # @return [Array<Hash>] photo entries: { "url" => rehosted_url, "alt" => ..., "source_url" => original }
  def photos
    Array.wrap(media).select { |m| m["type"] == "photo" && m["url"].present? }
  end

  # True once we have enough captured content to render a standalone archive card.
  def renderable?
    text_html.present? || text_content.present? || photos.any?
  end

  # True when the original source is gone but we still hold a usable snapshot.
  def archived_fallback?
    deleted? && renderable?
  end

  def stale_for_liveness?
    checked_at.nil? || checked_at < LIVENESS_TTL.ago
  end
end
