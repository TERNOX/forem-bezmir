module Admin
  # This controller is solely responsible for rendering the settings page at
  # /admin/customization/config. The actual updates get handled by the settings
  # controllers in the Admin::Settings namespace.
  class SettingsController < Admin::ApplicationController
    # NOTE: The "show" action uses a lot of partials, this makes it easier to
    # reference them.
    prepend_view_path("app/views/admin/settings")

    layout "admin"

    def show
      @logo_allowed_types = LogoUploader::ALLOWED_TYPES
      @logo_max_file_size = LogoUploader::MAX_FILE_SIZE
      @confirmation_text =
        I18n.t("admin.settings_controller.confirmation", username: current_user.username)
      @digest_frequency_days = ::Settings::General.periodic_email_digest.to_i
      @last_digest_sent_at = fetch_last_digest_timestamp
      @next_digest_scheduled_at = compute_next_digest_timestamp(
        @last_digest_sent_at,
        @digest_frequency_days,
      )
      @last_test_digest_attempt = ::EmailDigestTestAttempt
        .includes(:user, :logs)
        .recent_first
        .first
    end

    private

    # We need to override this method from Admin::ApplicationController since
    # there is no resource to authorize.
    def authorization_resource; end

    def fetch_last_digest_timestamp
      return unless defined?(EmailMessage)

      EmailMessage
        .where(mailer: "DigestMailer#digest_email")
        .maximum(:sent_at)
        &.in_time_zone(Time.zone)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      Rails.logger.warn("Unable to load last digest timestamp: #{e.class}: #{e.message}")
      nil
    end

    def compute_next_digest_timestamp(last_sent_at, frequency_days)
      return unless frequency_days.positive?

      reference = last_sent_at&.in_time_zone(Time.zone)
      return Time.zone.now + frequency_days.days if reference.blank?

      candidate = reference + frequency_days.days
      return candidate if candidate.future?

      cycles = ((Time.zone.now - reference) / frequency_days.days.to_f).ceil
      reference + cycles * frequency_days.days
    end
  end
end
