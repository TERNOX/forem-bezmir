module Admin
  module Settings
    class EmailDigestsController < Admin::Settings::BaseController
      def create
        email = test_digest_params[:email].to_s.strip.downcase
        if email.blank?
          render json: {
            error: I18n.t("admin.settings.email_digests_controller.email_required")
          }, status: :unprocessable_entity
          return
        end

        user = User.find_by("LOWER(email) = ?", email)

        unless user
          render json: {
            error: I18n.t(
              "admin.settings.email_digests_controller.user_missing",
              email: test_digest_params[:email],
            )
          }, status: :unprocessable_entity
          return
        end

        begin
          if ForemInstance.dev_to?
            Emails::SendUserDigestWorker.new.perform(user.id)
          else
            Emails::SendUserDigestWorker.perform_async(user.id)
          end
        rescue StandardError => e
          Honeybadger.notify(e)
          render json: {
            error: I18n.t("admin.settings.email_digests_controller.delivery_failed"),
          }, status: :internal_server_error
          return
        end

        Audit::Logger.log(:internal, current_user, params.dup)

        render json: {
          message: I18n.t(
            "admin.settings.email_digests_controller.test_sent",
            email: user.email,
          )
        }, status: :ok
      end

      private

      def authorization_resource
        ::Settings::General
      end

      def test_digest_params
        params.require(:test_digest).permit(:email)
      end
    end
  end
end
