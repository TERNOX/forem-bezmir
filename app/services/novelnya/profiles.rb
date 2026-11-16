module Novelnya
  # Fork-only: members of Новельня (novelnya.com, the Ukrainian visual-novel
  # hosting site that logs in via Kutok) who chose to show the link between
  # their accounts. Новельня publishes that opt-in list; we pull it in the
  # background (Novelnya::SyncProfilesWorker) and keep it in the cache, so a
  # profile page here only reads the cache and never waits on another site.
  class Profiles
    BASE_URL = ENV.fetch("NOVELNYA_URL", "https://novelnya.com").chomp("/").freeze
    CACHE_KEY = "novelnya:profiles:v1".freeze
    # A missed sync keeps the last good list; if Новельня stays unreachable
    # (or closes its site) for this long, the links quietly disappear.
    CACHE_TTL = 6.hours
    TIMEOUT_SECONDS = 10
    MAX_PROJECTS = 4

    class << self
      # The Новельня profile for a Kutok user id, or nil.
      def for(user_id)
        profiles = Rails.cache.read(CACHE_KEY)
        profiles.is_a?(Hash) ? profiles[user_id.to_i] : nil
      end

      # Pulls the list and stores it. Returns the ids whose entry changed
      # (added, removed or edited), or nil when the fetch failed; a failure
      # leaves the cached list as it was.
      def refresh!
        profiles = fetch
        return unless profiles

        previous = Rails.cache.read(CACHE_KEY)
        previous = {} unless previous.is_a?(Hash)
        Rails.cache.write(CACHE_KEY, profiles, expires_in: CACHE_TTL)

        (previous.keys | profiles.keys).reject { |id| previous[id] == profiles[id] }
      end

      private

      def fetch
        response = HTTParty.get(
          "#{BASE_URL}/embed/kutok/profiles",
          headers: {
            "Accept" => "application/json",
            "User-Agent" => "#{Settings::Community.community_name} (#{URL.url})"
          },
          timeout: TIMEOUT_SECONDS,
          follow_redirects: false,
        )
        return unless response.code == 200

        data = response.parsed_response
        return unless data.is_a?(Hash) && data["profiles"].is_a?(Array)

        data["profiles"].filter_map { |item| sanitize(item) }.index_by { |profile| profile[:kutok_user_id] }
      rescue StandardError => e
        Rails.logger.warn("Novelnya::Profiles: fetch failed: #{e.class}: #{e.message}")
        nil
      end

      # Everything comes from another site: keep only expected types, and
      # links that point at Новельня (profile, game pages) or https images.
      def sanitize(item)
        return unless item.is_a?(Hash)

        id = item["kutok_user_id"]
        url = item["url"].to_s
        return unless id.is_a?(Integer) && id.positive? && url.start_with?("#{BASE_URL}/users/")

        {
          kutok_user_id: id,
          name: item["name"].to_s.strip.truncate(120).presence,
          username: item["username"].to_s.strip.truncate(60).presence,
          url: url,
          avatar_url: https(item["avatar_url"]),
          projects: Array(item["projects"]).filter_map { |project| sanitize_project(project) }.first(MAX_PROJECTS)
        }
      end

      def sanitize_project(project)
        return unless project.is_a?(Hash)

        title = project["title"].to_s.strip
        url = project["url"].to_s
        return if title.blank? || !url.start_with?("#{BASE_URL}/projects/")

        { title: title.truncate(120), url: url, cover_url: https(project["cover_url"]) }
      end

      def https(value)
        value.is_a?(String) && value.start_with?("https://") ? value : nil
      end
    end
  end
end
