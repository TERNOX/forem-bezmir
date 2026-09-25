module Settings
  class RateLimit < Base
    self.table_name = :settings_rate_limits

    setting :agent_session_creation, type: :integer, default: 5
    setting :article_update, type: :integer, default: 30
    setting :comment_antispam_creation, type: :integer, default: 1
    # Explicitly defaults to 7 to accommodate DEV Top 7 Posts
    setting :mention_creation, type: :integer, default: 7
    setting :comment_creation, type: :integer, default: 9
    setting :email_recipient, type: :integer, default: 5
    setting :feedback_message_creation, type: :integer, default: 5
    setting :follow_count_daily, type: :integer, default: 500
    setting :image_upload, type: :integer, default: 9
    setting :video_upload, type: :integer, default: 3
    setting :listing_creation, type: :integer, default: 1
    setting :organization_creation, type: :integer, default: 1
    setting :organization_invitation_daily, type: :integer, default: 3
    setting :organization_invitation_max_outstanding, type: :integer, default: 10
    setting :published_article_antispam_creation, type: :integer, default: 1
    setting :published_article_creation, type: :integer, default: 9
    setting :reaction_creation, type: :integer, default: 10
    setting :send_email_confirmation, type: :integer, default: 2
    setting :spam_trigger_terms, type: :array, default: []
    setting :user_considered_new_days, type: :integer, default: 3
    setting :user_subscription_creation, type: :integer, default: 3
    setting :user_update, type: :integer, default: 15

    # Moderation
    setting :internal_content_description_spec, type: :string
    setting :ai_spam_moderation_enabled, type: :boolean, default: true
    setting :ai_moderation_model, type: :string
    setting :spam_exempt_usernames, type: :array, default: []
    setting :spam_exempt_organization_slugs, type: :array, default: []

    # Spam checks run in Sidekiq without a request/subforem context. Keep these
    # installation-wide controls global even when edited from a subforem domain.
    GLOBAL_SETTING_KEYS = %i[
      ai_spam_moderation_enabled ai_moderation_model spam_exempt_usernames spam_exempt_organization_slugs
    ].freeze

    class << self
      GLOBAL_SETTING_KEYS.each do |key|
        define_method(key) do |**_options|
          value = all_settings(nil)[key.to_s]
          value = get_default(key) if value.nil?
          convert_string_to_value_type(get_setting(key)[:type], value)
        end

        define_method(:"set_#{key}") do |value, **_options|
          record = find_or_initialize_by(var: key.to_s, subforem_id: nil)
          record.value = convert_string_to_value_type(get_setting(key)[:type], value)
          record.save!
          clear_cache
          value
        end

        define_method(:"#{key}=") do |value|
          public_send(:"set_#{key}", value)
        end
      end
    end

    # A helper function to determine if we should consider the user a "new" user.
    #
    # @note A "new" user is more likely to start spamming than an "old" user.
    #
    # @param user [User, UserDecorator]
    #
    # @return [Boolean]
    def self.user_considered_new?(user:)
      return true unless user
      return false unless user_considered_new_days.positive?

      user.created_at.after?(user_considered_new_days.days.ago)
    end

    # A helper function to determine if text is spammy.
    #
    # @param text [String] text to check for "spamminess"
    #
    # @return [TrueClass] if this is spammy
    # @return [FalseClass] if this isn't spammy
    def self.trigger_spam_for?(text:)
      return false if spam_trigger_terms.empty?

      regexp = Regexp.new("(#{spam_trigger_terms.map { |term| Regexp.escape(term) }.join('|')})", true)
      regexp.match?(text)
    end

    # Whether the Gemini-powered spam/content moderation checks should run.
    #
    # @return [Boolean] true only when a Gemini API key is configured and the
    #   admin has not switched AI moderation off.
    def self.ai_spam_moderation?
      Ai::Base::DEFAULT_KEY.present? && ai_spam_moderation_enabled
    end

    # The Gemini model used by the moderation checks.
    #
    # @param default [String] the model to use when the admin has not picked one
    #
    # @return [String]
    def self.ai_moderation_model_or(default)
      ai_moderation_model.presence || default
    end

    # Whether the given author is exempt from automatic spam flagging.
    #
    # @param user [User, nil] the author
    # @param organization [Organization, nil] the organization the content was published under
    #
    # @return [Boolean]
    def self.spam_exempt?(user:, organization: nil)
      if user && normalized_list(spam_exempt_usernames).include?(user.username.to_s.downcase)
        return true
      end

      organization.present? &&
        normalized_list(spam_exempt_organization_slugs).include?(organization.slug.to_s.downcase)
    end

    def self.normalized_list(values)
      values.map { |value| value.to_s.strip.delete_prefix("@").downcase }.compact_blank
    end
    private_class_method :normalized_list
  end
end
