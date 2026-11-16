# Fork-only: a game card from Новельня (novelnya.com), the community's site for
# Ukrainian visual novels and games.
#
#   {% novelnya misto-sniv %}
#   {% embed https://novelnya.com/projects/misto-sniv %}
#
# The card data comes from Новельня's public endpoint
# (/embed/kutok/projects/:slug). It only answers for games in its catalog that
# are not 18+, since the card shows here outside Новельня's age gate; anything
# else renders as a plain link. The data is fetched when the article is saved
# (liquid renders into processed_html) and cached briefly, so a slow or down
# Новельня never breaks the article: the link card is the fallback.
class NovelnyaTag < LiquidTagBase
  PARTIAL = "liquids/novelnya".freeze
  BASE_URL = ENV.fetch("NOVELNYA_URL", "https://novelnya.com").chomp("/").freeze
  SLUG = "[A-Za-z0-9][A-Za-z0-9_%-]*".freeze
  REGISTRY_REGEXP = %r{\Ahttps?://(?:www\.)?novelnya\.com/projects/(?<slug>#{SLUG})/?(?:[?#]\S*)?\z}i
  SLUG_REGEXP = /\A(?<slug>#{SLUG})\z/
  CACHE_TTL = 30.minutes
  TIMEOUT_SECONDS = 5
  MAX_TAGS = 4

  def initialize(_tag_name, input, _parse_context)
    super
    input = CGI.unescape_html(strip_tags(input)).strip
    match = REGISTRY_REGEXP.match(input) || SLUG_REGEXP.match(input)
    raise StandardError, I18n.t("liquid_tags.novelnya_tag.invalid_url") unless match

    @slug = CGI.unescape(match[:slug])
  end

  def render(_context)
    ApplicationController.render(partial: PARTIAL, locals: { game: game, url: project_url })
  end

  private

  def project_url
    "#{BASE_URL}/projects/#{ERB::Util.url_encode(@slug)}"
  end

  def game
    Rails.cache.fetch("novelnya_tag:#{@slug}", expires_in: CACHE_TTL, skip_nil: true) { fetch_game }
  rescue StandardError => e
    Rails.logger.warn("NovelnyaTag: card for #{@slug} failed: #{e.class}: #{e.message}")
    nil
  end

  def fetch_game
    response = HTTParty.get(
      "#{BASE_URL}/embed/kutok/projects/#{ERB::Util.url_encode(@slug)}",
      headers: { "Accept" => "application/json", "User-Agent" => "#{Settings::Community.community_name} (#{URL.url})" },
      timeout: TIMEOUT_SECONDS,
      follow_redirects: false,
    )
    return unless response.code == 200

    data = response.parsed_response
    data.is_a?(Hash) ? sanitize(data) : nil
  end

  # Everything comes from another site: keep only expected types, and links
  # that point at Новельня (game page) or at an https image.
  def sanitize(data)
    title = data["title"].to_s.strip
    url = data["url"].to_s
    return if title.blank? || !url.start_with?("#{BASE_URL}/projects/")

    {
      title: title.truncate(200),
      url: url,
      cover_url: data["cover_url"].to_s.start_with?("https://") ? data["cover_url"] : nil,
      developer: data["developer"].presence&.to_s&.truncate(120),
      year: data["year"].is_a?(Integer) ? data["year"] : nil,
      excerpt: data["excerpt"].presence&.to_s&.truncate(300),
      tags: Array(data["tags"]).grep(String).map { |tag| tag.truncate(40) }.first(MAX_TAGS)
    }
  end
end

Liquid::Template.register_tag("novelnya", NovelnyaTag)

UnifiedEmbed.register(NovelnyaTag, regexp: NovelnyaTag::REGISTRY_REGEXP, skip_validation: true)
