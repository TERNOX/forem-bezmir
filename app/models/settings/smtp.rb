module Settings
  class SMTP < Base
    self.table_name = :settings_smtp
    AUTHENTICATION_METHODS = %w[plain login cram_md5].freeze

    setting :automatic_digests_enabled, type: :boolean, default: true
    setting :address, type: :string, default: ApplicationConfig["SMTP_ADDRESS"].presence
    setting :authentication, type: :string, default: ApplicationConfig["SMTP_AUTHENTICATION"].presence,
                             validates: { inclusion: AUTHENTICATION_METHODS }
    setting :domain, type: :string, default: ApplicationConfig["SMTP_DOMAIN"].presence
    setting :password, type: :string, default: ApplicationConfig["SMTP_PASSWORD"].presence
    setting :port, type: :integer, default: ApplicationConfig["SMTP_PORT"].presence || 25
    setting :user_name, type: :string, default: ApplicationConfig["SMTP_USER_NAME"].presence
    setting :from_email_address, type: :string, default: ApplicationConfig["DEFAULT_EMAIL"].presence,
                                 validates: { email: true, allow_blank: true }
    setting :reply_to_email_address, type: :string, default: ApplicationConfig["DEFAULT_EMAIL"].presence,
                                     validates: { email: true, allow_blank: true }

    class << self
      # Digest production runs without a request/subforem context. Keep this
      # installation-wide switch global even when edited from a subforem domain.
      def automatic_digests_enabled(**_options)
        value = all_settings(nil)["automatic_digests_enabled"]
        value.nil? ? get_default(:automatic_digests_enabled) : value
      end

      def set_automatic_digests_enabled(value, **_options)
        record = find_or_initialize_by(var: "automatic_digests_enabled", subforem_id: nil)
        record.value = convert_string_to_value_type(:boolean, value)
        record.save!
        clear_cache
        value
      end

      def automatic_digests_enabled=(value)
        set_automatic_digests_enabled(value)
      end

      def settings
        if provided_minimum_settings?
          custom_provider_settings
        else
          fallback_sendgrid_settings
        end
      end

      def provided_minimum_settings?
        address.present? && user_name.present? && password.present?
      end

      private

      def custom_provider_settings
        to_h.except(:automatic_digests_enabled)
      end

      def fallback_sendgrid_settings
        {
          address: "smtp.sendgrid.net",
          port: 587,
          authentication: :plain,
          user_name: "apikey",
          password: ENV.fetch("SENDGRID_API_KEY", nil),
          domain: ::Settings::General.app_domain
        }
      end
    end
  end
end
