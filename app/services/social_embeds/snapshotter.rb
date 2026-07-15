module SocialEmbeds
  # Finds or creates a SocialPostSnapshot for an embedded post and populates it
  # from the platform client. Core guarantee: a successful capture is durable —
  # on :deleted or :unavailable we NEVER wipe previously stored text/photos, we
  # only update the source_status. This is what lets an article keep its quote
  # after the original post is gone, and what makes article reprocessing safe.
  class Snapshotter
    # How long a captured snapshot is trusted before we re-check the source.
    STALE_AFTER = 12.hours

    def self.call(platform:, source_id:, source_url:, at_uri: nil)
      new(platform: platform, source_id: source_id, source_url: source_url, at_uri: at_uri).call
    end

    # Re-check an existing snapshot (used by the refresh worker).
    def self.refresh(snapshot)
      instance = new(
        platform: snapshot.platform,
        source_id: snapshot.source_id,
        source_url: snapshot.source_url,
        at_uri: snapshot.at_uri,
      )
      instance.refresh!(snapshot)
      snapshot.save! if snapshot.changed?
      snapshot
    end

    def initialize(platform:, source_id:, source_url:, at_uri: nil)
      @platform = platform.to_s
      @source_id = source_id.to_s
      @source_url = source_url
      @at_uri = at_uri
    end

    def call
      snapshot = SocialPostSnapshot.find_or_initialize_by(platform: @platform, source_id: @source_id)
      snapshot.source_url = @source_url if snapshot.source_url.blank?
      snapshot.at_uri = @at_uri if @at_uri.present? && snapshot.at_uri.blank?

      refresh!(snapshot) if should_fetch?(snapshot)
      snapshot.save! if snapshot.new_record? || snapshot.changed?
      snapshot
    rescue StandardError => e
      Rails.logger.error(
        "SocialEmbeds::Snapshotter failed for #{@platform}:#{@source_id}: #{e.class}: #{e.message}",
      )
      snapshot || SocialPostSnapshot.new(platform: @platform, source_id: @source_id, source_url: @source_url)
    end

    def refresh!(snapshot)
      data = client.fetch(source_id: @source_id, source_url: @source_url, at_uri: @at_uri)
      snapshot.checked_at = Time.current

      case data.status
      when :ok
        apply_content(snapshot, data)
        snapshot.source_status = :live
        snapshot.fetched_at = Time.current
      when :deleted
        # Keep whatever we captured before; just record that the source is gone.
        snapshot.source_status = :deleted
      when :unavailable
        # Don't downgrade a good snapshot on a transient failure.
        snapshot.source_status = :unavailable unless snapshot.renderable?
      end

      snapshot
    end

    private

    def should_fetch?(snapshot)
      return true if snapshot.new_record?
      return true if snapshot.unknown?

      snapshot.checked_at.nil? || snapshot.checked_at < STALE_AFTER.ago
    end

    def client
      @platform == "bluesky" ? SocialEmbeds::BlueskyClient : SocialEmbeds::TwitterClient
    end

    def apply_content(snapshot, data)
      snapshot.author_handle = data.author_handle if data.author_handle.present?
      snapshot.author_name = data.author_name if data.author_name.present?
      snapshot.author_avatar_url = data.author_avatar_url if data.author_avatar_url.present?
      snapshot.text_content = data.text_content if data.text_content.present?
      snapshot.text_html = SocialEmbeds::TextFormatter.call(data.text_content) if data.text_content.present?
      snapshot.posted_at = data.posted_at if data.posted_at.present?
      snapshot.media = rehost_photos(snapshot, data.photos)
    end

    # Downloads each source photo onto our own storage. Reuses previously stored
    # entries (keyed by original source_url) so refreshes don't re-download.
    def rehost_photos(snapshot, photos)
      existing = Array.wrap(snapshot.media)
      return existing if photos.blank?

      Array.wrap(photos).filter_map do |photo|
        prior = existing.detect { |m| m["source_url"] == photo["url"] && m["url"].present? }
        next prior if prior

        stored_url = SocialEmbedImageUploader.new.upload_from_url(photo["url"])
        next nil unless stored_url

        {
          "type" => "photo",
          "url" => stored_url,
          "source_url" => photo["url"],
          "alt" => photo["alt"].to_s
        }
      end
    end
  end
end
