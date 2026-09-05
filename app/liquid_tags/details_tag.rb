class DetailsTag < Liquid::Block
  include ActionView::Helpers::SanitizeHelper

  PARTIAL = "liquids/details".freeze

  # Keeps all of RenderedMarkdownScrubber's defense-in-depth sanitization (safe
  # table-cell text-align re-application, stripping Liquid tag syntax from
  # attribute values, codeblock handling) and only extends its allowlist with the
  # block-level elements that nested liquid embeds (e.g. {% embed %}, {% comment %},
  # {% youtube %}) produce. Without div/iframe the sanitizer strips the structural
  # HTML and the embed renders broken. Mirrors the sibling ColTag pattern
  # (+ class/loading) and adds the iframe-specific attribute embeds rely on.
  # `style` is intentionally excluded to avoid a CSS/XSS surface, matching Forem's
  # own FEED embed allowlist.
  class EmbedFriendlyScrubber < RenderedMarkdownScrubber
    ADDITIONAL_TAGS = %w[div iframe].freeze
    ADDITIONAL_ATTRIBUTES = %w[class loading allowfullscreen].freeze

    def initialize
      super
      self.tags = MarkdownProcessor::AllowedTags::RENDERED_MARKDOWN_SCRUBBER + ADDITIONAL_TAGS
      self.attributes = MarkdownProcessor::AllowedAttributes::RENDERED_MARKDOWN_SCRUBBER + ADDITIONAL_ATTRIBUTES
    end
  end

  # Hosts whose iframes are the product of a trusted Liquid embed. The scrubber
  # allows the <iframe> tag so nested embeds render, but the RENDERED_MARKDOWN
  # attribute allowlist also permits `src`, which would otherwise let an author
  # drop a raw <iframe src="https://attacker"> into a {% details %} block (the
  # site CSP permits arbitrary https frames). We strip any iframe whose src host
  # is not on this list after sanitizing.
  ALLOWED_IFRAME_HOST_SUFFIXES = %w[
    youtube.com youtube-nocookie.com player.vimeo.com codepen.io codesandbox.io
    jsfiddle.net jsitor.com replit.com repl.it glitch.com stackblitz.com
    player.twitch.tv clips.twitch.tv speakerdeck.com slideshare.net
    w.soundcloud.com open.spotify.com asciinema.org loom.com platform.twitter.com
    kotlinlang.org runkit.com mml.dev stackery.io huggingface.co
  ].freeze

  def initialize(_tag_name, summary, _parse_context)
    super
    @summary = sanitize(summary.strip)
  end

  def render(_context)
    content = Nokogiri::HTML.parse(super)
    parsed_content = sanitize(
      content.xpath("//html/body").inner_html,
      scrubber: EmbedFriendlyScrubber.new,
    )
    parsed_content = strip_untrusted_iframes(parsed_content)

    ApplicationController.render(
      partial: PARTIAL,
      locals: {
        summary: @summary,
        parsed_content: parsed_content
      },
    )
  end

  private

  def strip_untrusted_iframes(html)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css("iframe").each do |iframe|
      iframe.remove unless trusted_iframe_src?(iframe["src"])
    end
    # sanitize returned an html_safe buffer; preserve that so the partial renders
    # the markup instead of escaping it.
    fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety
  end

  def trusted_iframe_src?(src)
    return false if src.blank?

    uri = URI.parse(src)
    return false unless uri.scheme == "https"

    host = uri.host&.downcase
    return false if host.blank?

    ALLOWED_IFRAME_HOST_SUFFIXES.any? { |suffix| host == suffix || host.end_with?(".#{suffix}") }
  rescue URI::InvalidURIError
    false
  end
end

Liquid::Template.register_tag("collapsible", DetailsTag)
Liquid::Template.register_tag("details", DetailsTag)
Liquid::Template.register_tag("spoiler", DetailsTag)
