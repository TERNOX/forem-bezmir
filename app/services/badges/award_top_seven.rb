module Badges
  class AwardTopSeven
    DEFAULT_BADGE_SLUG = "top-7".freeze

    def self.call(usernames, message_markdown = default_message_markdown)
      users = User.where(username: usernames)

      # The reputation modifier changes are now handled automatically
      # via the BadgeAchievement callback when badges are awarded
      ::Badges::Award.call(
        users,
        badge_slug,
        message_markdown,
      )
    end

    def self.default_message_markdown
      I18n.t("services.badges.congrats", community: Settings::Community.community_name)
    end

    def self.badge_slug
      slug = Settings::General.top_articles_badge_slug
      slug.present? ? slug : DEFAULT_BADGE_SLUG
    end
  end
end
