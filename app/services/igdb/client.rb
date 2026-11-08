# Fork-only: minimal IGDB API v4 client (https://api-docs.igdb.com).
# Authenticates with a Twitch app (client credentials flow); the access token is
# cached until shortly before it expires and refreshed once on a 401.
module Igdb
  class Client
    TOKEN_URL = "https://id.twitch.tv/oauth2/token".freeze
    API_URL = "https://api.igdb.com/v4".freeze
    TIMEOUT = 10
    TOKEN_CACHE_KEY = "igdb/access_token".freeze
    GAME_FIELDS = %w[
      name url first_release_date
      cover.image_id artworks.image_id screenshots.image_id
      platforms.abbreviation platforms.name
    ].join(",").freeze

    class Error < StandardError; end
    class NotConfigured < Error; end

    Result = Struct.new(:igdb_id, :title, :url, :release_year, :platforms,
                        :cover_image_id, :artwork_image_id, keyword_init: true) do
      def cover_url(size = "t_cover_big")
        Game.igdb_image_url(cover_image_id, size)
      end

      def artwork_url(size = "t_screenshot_big")
        Game.igdb_image_url(artwork_image_id, size)
      end

      def as_json(*)
        to_h.merge(cover_url: cover_url, artwork_url: artwork_url)
      end
    end

    def self.configured?
      Settings::General.igdb_client_id.present? && Settings::General.igdb_client_secret.present?
    end

    # @return [Array<Result>]
    def search(query, limit: 12)
      query = query.to_s.strip
      return [] if query.blank?

      body = %(search "#{escape(query)}"; fields #{GAME_FIELDS}; limit #{limit.to_i.clamp(1, 50)};)
      games_request(body)
    end

    # @return [Result, nil]
    def find(igdb_id)
      games_request("fields #{GAME_FIELDS}; where id = #{Integer(igdb_id)};").first
    end

    private

    def games_request(body)
      raise NotConfigured, "IGDB credentials are not set" unless self.class.configured?

      response = post_games(body)
      if response.code == 401
        Rails.cache.delete(TOKEN_CACHE_KEY)
        response = post_games(body)
      end
      raise Error, "IGDB request failed (HTTP #{response.code})" unless response.success?

      Array(response.parsed_response).map { |game| build_result(game) }
    rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise Error, "IGDB request failed: #{e.class}"
    end

    def post_games(body)
      HTTParty.post(
        "#{API_URL}/games",
        body: body,
        timeout: TIMEOUT,
        headers: {
          "Client-ID" => Settings::General.igdb_client_id,
          "Authorization" => "Bearer #{access_token}",
          "Accept" => "application/json"
        },
      )
    end

    def access_token
      cached = Rails.cache.read(TOKEN_CACHE_KEY)
      return cached if cached.present?

      response = HTTParty.post(
        TOKEN_URL,
        timeout: TIMEOUT,
        query: {
          client_id: Settings::General.igdb_client_id,
          client_secret: Settings::General.igdb_client_secret,
          grant_type: "client_credentials"
        },
      )
      raise Error, "IGDB authentication failed (HTTP #{response.code})" unless response.success?

      token = response.parsed_response["access_token"]
      expires_in = response.parsed_response["expires_in"].to_i
      Rails.cache.write(TOKEN_CACHE_KEY, token, expires_in: [expires_in - 3600, 300].max)
      token
    end

    def build_result(game)
      artwork = Array(game["artworks"]).first || Array(game["screenshots"]).first
      Result.new(
        igdb_id: game["id"],
        title: game["name"],
        url: game["url"],
        release_year: game["first_release_date"] && Time.zone.at(game["first_release_date"]).year,
        platforms: Array(game["platforms"]).filter_map { |p| p["abbreviation"].presence || p["name"] },
        cover_image_id: game.dig("cover", "image_id"),
        artwork_image_id: artwork&.dig("image_id"),
      )
    end

    def escape(text)
      text.delete("\\").gsub('"', '\"').delete(";")
    end
  end
end
