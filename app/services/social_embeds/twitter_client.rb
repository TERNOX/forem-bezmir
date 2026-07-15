module SocialEmbeds
  # Fetches a Twitter/X post. X has no free official API, so we use two
  # unofficial-but-public paths, best-effort:
  #   1. syndication (cdn.syndication.twimg.com/tweet-result) -> text + author + PHOTOS
  #   2. oEmbed (publish.twitter.com/oembed)                  -> text + author (fallback)
  # Deletion is detected via HTTP 404 / tombstone on either path.
  class TwitterClient
    SYNDICATION = "https://cdn.syndication.twimg.com/tweet-result".freeze
    OEMBED = "https://publish.twitter.com/oembed".freeze

    def self.fetch(source_id:, source_url:, **_kwargs)
      new(source_id, source_url).fetch
    end

    def initialize(source_id, source_url)
      @id = source_id.to_s
      @url = source_url
    end

    def fetch
      syndicated = fetch_syndication
      return syndicated if syndicated && (syndicated.ok? || syndicated.status == :deleted)

      fetch_oembed
    end

    private

    # @return [PostData, nil] nil means "try the fallback"
    def fetch_syndication
      response = HTTParty.get(
        SYNDICATION,
        query: { id: @id, token: TwitterSyndicationToken.call(@id), lang: "en" },
        headers: {
          "Accept" => "application/json",
          "User-Agent" => "Mozilla/5.0 (compatible; ForemSocialEmbed/1.0)"
        },
        timeout: 10,
      )

      return PostData.deleted if response.code == 404
      return unless response.code == 200

      data = response.parsed_response
      return unless data.is_a?(Hash)
      return PostData.deleted if data["__typename"] == "TweetTombstone"

      user = data["user"] || {}
      PostData.new(
        status: :ok,
        author_handle: user["screen_name"],
        author_name: user["name"].presence || user["screen_name"],
        author_avatar_url: user["profile_image_url_https"],
        text_content: data["text"],
        text_html: nil,
        posted_at: parse_time(data["created_at"]),
        photos: extract_photos(data),
        raw: {},
      )
    rescue StandardError => e
      Rails.logger.warn("SocialEmbeds::TwitterClient syndication error for #{@id}: #{e.class}: #{e.message}")
      nil
    end

    def extract_photos(data)
      photos = data["photos"].presence ||
        Array.wrap(data["mediaDetails"]).select { |m| m["type"] == "photo" }

      Array.wrap(photos).filter_map do |photo|
        url = photo["url"].presence || photo["media_url_https"].presence
        next unless url

        { "url" => url, "alt" => photo["ext_alt_text"].to_s }
      end
    end

    def fetch_oembed
      response = HTTParty.get(
        OEMBED,
        query: { url: @url, omit_script: 1, dnt: true, hide_thread: true },
        headers: { "Accept" => "application/json" },
        timeout: 10,
      )

      return PostData.deleted if response.code == 404
      return PostData.unavailable(raw: { "code" => response.code }) unless response.code == 200

      data = response.parsed_response
      return PostData.unavailable unless data.is_a?(Hash)

      PostData.new(
        status: :ok,
        author_handle: data["author_url"].to_s.split("/").last.presence,
        author_name: data["author_name"],
        author_avatar_url: nil,
        text_content: oembed_text(data["html"]),
        text_html: nil,
        posted_at: nil,
        photos: [],
        raw: {},
      )
    rescue StandardError => e
      Rails.logger.warn("SocialEmbeds::TwitterClient oembed error for #{@id}: #{e.class}: #{e.message}")
      PostData.unavailable
    end

    def oembed_text(html)
      return if html.blank?

      fragment = Nokogiri::HTML.fragment(html)
      paragraph = fragment.at_css("blockquote p")
      (paragraph&.text || fragment.text).to_s.strip.presence
    end

    def parse_time(str)
      Time.zone.parse(str) if str.present?
    rescue ArgumentError, TypeError
      nil
    end
  end
end
