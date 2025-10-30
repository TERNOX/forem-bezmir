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
      @digest_frequency_days = Settings::General.periodic_email_digest.to_i
      @last_digest_sent_at = EmailMessage
        .where(mailer: "DigestMailer#digest_email")
        .maximum(:sent_at)&.in_time_zone(Time.zone)
      @next_digest_scheduled_at =
        if @last_digest_sent_at.present? && @digest_frequency_days.positive?
          candidate = @last_digest_sent_at + @digest_frequency_days.days
          if candidate < Time.zone.now
            cycles = ((Time.zone.now - @last_digest_sent_at) / @digest_frequency_days.days.to_f).ceil
            @last_digest_sent_at + cycles * @digest_frequency_days.days
          else
            candidate
          end
        end
      @next_digest_scheduled_at ||= Time.zone.now + @digest_frequency_days.days if @digest_frequency_days.positive?
    end

    private

    # We need to override this method from Admin::ApplicationController since
    # there is no resource to authorize.
    def authorization_resource; end
  end
end
