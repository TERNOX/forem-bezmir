module SocialEmbeds
  # Fetches a Bluesky post via the public, unauthenticated AT-Protocol API.
  # No API key required. Returns a SocialEmbeds::PostData.
  class BlueskyClient
    ENDPOINT = "https://public.api.bsky.app/xrpc/app.bsky.feed.getPostThread".freeze
    RESOLVE_ENDPOINT = "https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle".freeze
    AT_URI_REGEXP = %r{\Aat://(?<authority>[^/]+)/(?<collection>[^/]+)/(?<rkey>[^/]+)\z}

    def self.fetch(at_uri:, **_kwargs)
      new(at_uri).fetch
    end

    # The getPostThread API only accepts DID-based AT-URIs — a handle-based one
    # (what users' bsky.app URLs produce) returns notFound. Resolve the handle to
    # its stable DID so capture works and the snapshot is keyed canonically.
    # Falls back to the input if resolution fails.
    def self.canonical_at_uri(at_uri)
      match = at_uri.to_s.match(AT_URI_REGEXP)
      return at_uri unless match
      return at_uri if match[:authority].start_with?("did:")

      did = resolve_handle(match[:authority])
      did ? "at://#{did}/#{match[:collection]}/#{match[:rkey]}" : at_uri
    end

    def self.resolve_handle(handle)
      response = HTTParty.get(RESOLVE_ENDPOINT, query: { handle: handle },
                                                headers: { "Accept" => "application/json" }, timeout: 10)
      response.code == 200 ? response.parsed_response["did"].presence : nil
    rescue StandardError => e
      Rails.logger.warn("SocialEmbeds::BlueskyClient resolve_handle failed for #{handle}: #{e.class}: #{e.message}")
      nil
    end

    def initialize(at_uri)
      @at_uri = at_uri
    end

    def fetch
      return PostData.unavailable if @at_uri.blank?

      # Re-resolve to the DID form on every fetch: if resolution failed at capture
      # time a handle-based URI may be persisted, and getPostThread rejects those.
      # Resolving here lets scheduled refreshes recover such snapshots.
      uri = self.class.canonical_at_uri(@at_uri)

      response = HTTParty.get(
        ENDPOINT,
        query: { uri: uri, depth: 0, parentHeight: 0 },
        headers: { "Accept" => "application/json" },
        timeout: 10,
      )

      return PostData.deleted if not_found_error?(response)
      return PostData.unavailable(raw: { "code" => response.code }) unless response.code == 200

      thread = response.parsed_response.is_a?(Hash) ? response.parsed_response["thread"] : nil
      return PostData.deleted if thread.is_a?(Hash) && thread["$type"].to_s.include?("notFoundPost")
      return PostData.unavailable if !thread.is_a?(Hash) || !thread["post"].is_a?(Hash)

      build(thread["post"])
    rescue StandardError => e
      Rails.logger.warn("SocialEmbeds::BlueskyClient error for #{@at_uri}: #{e.class}: #{e.message}")
      PostData.unavailable
    end

    private

    def not_found_error?(response)
      response.code == 400 &&
        response.parsed_response.is_a?(Hash) &&
        response.parsed_response["error"].to_s.match?(/NotFound/i)
    end

    def build(post)
      author = post["author"] || {}
      record = post["record"] || {}

      PostData.new(
        status: :ok,
        author_handle: author["handle"],
        author_name: author["displayName"].presence || author["handle"],
        author_avatar_url: author["avatar"],
        text_content: record["text"],
        text_html: nil,
        posted_at: parse_time(record["createdAt"]),
        photos: extract_photos(post),
        raw: {},
      )
    end

    def extract_photos(post)
      embed = post["embed"] || {}
      images =
        if embed["$type"].to_s.include?("app.bsky.embed.images#view")
          embed["images"]
        elsif embed["media"].is_a?(Hash)
          embed["media"]["images"]
        end

      Array.wrap(images).filter_map do |img|
        url = img["fullsize"].presence || img["thumb"].presence
        next unless url

        { "url" => url, "alt" => img["alt"].to_s }
      end
    end

    def parse_time(str)
      Time.zone.parse(str) if str.present?
    rescue ArgumentError, TypeError
      nil
    end
  end
end
