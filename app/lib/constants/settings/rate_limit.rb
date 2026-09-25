module Constants
  module Settings
    module RateLimit
      def self.details
        {
          spam_trigger_terms: {
            description: I18n.t("lib.constants.settings.rate_limit.spam.description"),
            placeholder: I18n.t("lib.constants.settings.rate_limit.spam.placeholder")
          },
          user_considered_new_days: {
            description: I18n.t("lib.constants.settings.rate_limit.new_days.description"),
            placeholder: ::Settings::RateLimit.user_considered_new_days
          },
          internal_content_description_spec: {
            description: I18n.t("lib.constants.settings.rate_limit.content_spec.description"),
            placeholder: I18n.t("lib.constants.settings.rate_limit.content_spec.placeholder")
          },
          ai_spam_moderation_enabled: {
            title: I18n.t("lib.constants.settings.rate_limit.ai_moderation.title"),
            description: I18n.t("lib.constants.settings.rate_limit.ai_moderation.description"),
            key_present: I18n.t("lib.constants.settings.rate_limit.ai_moderation.key_present"),
            key_missing: I18n.t("lib.constants.settings.rate_limit.ai_moderation.key_missing")
          },
          ai_moderation_model: {
            title: I18n.t("lib.constants.settings.rate_limit.ai_model.title"),
            description: I18n.t("lib.constants.settings.rate_limit.ai_model.description",
                                model: Ai::Base::DEFAULT_MODEL),
            placeholder: I18n.t("lib.constants.settings.rate_limit.ai_model.placeholder")
          },
          ai_setup: {
            title: I18n.t("lib.constants.settings.rate_limit.ai_setup.title"),
            steps: I18n.t("lib.constants.settings.rate_limit.ai_setup.steps")
          },
          spam_exempt_usernames: {
            title: I18n.t("lib.constants.settings.rate_limit.exempt_users.title"),
            description: I18n.t("lib.constants.settings.rate_limit.exempt_users.description"),
            placeholder: I18n.t("lib.constants.settings.rate_limit.exempt_users.placeholder")
          },
          spam_exempt_organization_slugs: {
            title: I18n.t("lib.constants.settings.rate_limit.exempt_orgs.title"),
            description: I18n.t("lib.constants.settings.rate_limit.exempt_orgs.description"),
            placeholder: I18n.t("lib.constants.settings.rate_limit.exempt_orgs.placeholder")
          }
        }
      end
    end
  end
end
