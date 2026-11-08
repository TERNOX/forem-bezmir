# Fork-only: {% voting gra-roku-2026 %} (or a /vote/<slug> URL) embeds a card
# that invites readers to a community voting. The card is static (it ends up in
# cached article HTML), so it shows no live status or user data.
class VotingTag < LiquidTagBase
  PARTIAL = "liquids/voting".freeze
  REGISTRY_REGEXP = %r{\A(?:https?://[^/\s]+)?/vote/(?<slug>[0-9a-z\-_]+)/?(?:[?#]\S*)?\z}

  def initialize(_tag_name, markup, parse_context)
    super
    cleaned = ActionController::Base.helpers.strip_tags(markup).strip
    slug = cleaned.match(REGISTRY_REGEXP)&.[](:slug) || cleaned.downcase
    @voting = Voting.published.find_by(slug: slug)
    raise StandardError, I18n.t("liquid_tags.voting_tag.not_found") unless @voting
  end

  def render(_context)
    ApplicationController.render(
      partial: PARTIAL,
      locals: {
        voting: @voting,
        nominee_count: @voting.categories.count,
        preview_images: preview_images
      },
    )
  end

  private

  # Up to four covers from the voting's nominees, for a collage when there is no banner.
  def preview_images
    VotingNominee.joins(:category).where(voting_categories: { voting_id: @voting.id })
      .includes(:game).order("voting_categories.position", :position).limit(24)
      .filter_map { |nominee| nominee.image_url_for("cover") }.uniq.first(4)
  end
end

Liquid::Template.register_tag("voting", VotingTag)
UnifiedEmbed.register(VotingTag, regexp: VotingTag::REGISTRY_REGEXP, skip_validation: true)
