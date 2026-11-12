module SocialAutopost
  # Renders the Telegram message for an article from the template for its
  # kind (community, staff or digest). Templates use {{placeholders}}; a blank
  # template falls back to the localized default.
  class MessageBuilder
    MAX_LENGTH = 4096
    PLACEHOLDERS = %w[title author username url short_url organization tags description reading_time].freeze

    def self.default_template(kind)
      I18n.t("services.social_autopost.templates.#{kind}", locale: locale)
    end

    def self.template_for(kind)
      Settings::SocialAutopost.public_send(:"template_#{kind}").presence || default_template(kind)
    end

    def self.locale
      Settings::UserExperience.default_locale.presence || I18n.default_locale
    end

    def initialize(article, kind:, template: nil)
      @article = article
      @kind = kind
      @template = template
    end

    def call
      text = (template.presence || self.class.template_for(kind)).to_s.gsub("\r\n", "\n")
      replacements.each { |key, value| text = text.gsub("{{#{key}}}", value.to_s) }
      text = text.gsub(/\n{3,}/, "\n\n").strip
      text.truncate(MAX_LENGTH)
    end

    private

    attr_reader :article, :kind, :template

    def replacements
      {
        "title" => article.title,
        "author" => article.user&.name.presence || article.user&.username,
        "username" => article.user&.username,
        "url" => URL.article(article, user_signed_in: false),
        "short_url" => URL.url("/s/#{article.id}"),
        "organization" => article.organization&.name,
        "tags" => article.cached_tag_list.to_s.split(/[\s,]+/).compact_blank.map { |tag| "##{tag}" }.join(" "),
        "description" => article.description,
        "reading_time" => article.reading_time
      }
    end
  end
end
