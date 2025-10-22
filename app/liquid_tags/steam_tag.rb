class SteamTag < LiquidTagBase
  PARTIAL = "liquids/steam".freeze
  REGISTRY_REGEXP = %r{https?://store\.steampowered\.com/app/(?<app_id>\d+)(?:/[^/?#]+)?/?(?:\?[\w=&%-]*)?}i

  def initialize(_tag_name, input, _parse_context)
    super
    @app_id = parse_app_id(strip_tags(input))
  end

  def render(_context)
    ApplicationController.render(
      partial: PARTIAL,
      locals: {
        widget_src: widget_src,
      },
    )
  end

  private

  def parse_app_id(input)
    match = REGISTRY_REGEXP.match(input)
    raise StandardError, I18n.t("liquid_tags.steam_tag.invalid_url") unless match&.names&.include?("app_id")

    match[:app_id]
  end

  def widget_src
    "https://store.steampowered.com/widget/#{@app_id}/?l=ukrainian&theme=dark&transparent=1"
  end
end

Liquid::Template.register_tag("steam", SteamTag)

UnifiedEmbed.register(SteamTag, regexp: SteamTag::REGISTRY_REGEXP)
