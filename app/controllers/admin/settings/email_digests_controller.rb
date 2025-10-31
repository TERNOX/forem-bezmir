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

        attempt = ::EmailDigestTestAttempt.create!(user: user)

        begin
          if ForemInstance.dev_to?
            Emails::SendUserDigestWorker
              .new
              .perform(user.id, test_attempt_id: attempt.id)
          else
            job_id = Emails::SendUserDigestWorker.perform_async(user.id, test_attempt_id: attempt.id)

            if job_id.blank?
              attempt.mark_failed!(I18n.t("admin.settings.email_digests_controller.enqueue_failed"))
              render json: error_response_for(attempt), status: :internal_server_error
              return
            end

            attempt.update!(job_id: job_id)
          end
        rescue StandardError => e
          notice_id = Honeybadger.notify(e)
          attempt.mark_failed!(e, notice_id)
          render json: error_response_for(attempt), status: :internal_server_error
          return
        end

        Audit::Logger.log(:internal, current_user, params.dup)

        render json: success_response_for(attempt.reload), status: :ok
      end

      private

      def authorization_resource
        ::Settings::General
      end

      def test_digest_params
        params.require(:test_digest).permit(:email)
      end

      def success_response_for(attempt)
        {
          message: I18n.t(
            "admin.settings.email_digests_controller.status_messages.#{attempt.status}",
            email: attempt.display_email,
          ),
          status_html: render_status_html(attempt)
        }
      end

      def error_response_for(attempt)
        {
          error: I18n.t("admin.settings.email_digests_controller.delivery_failed"),
          status_html: render_status_html(attempt)
        }
      end

      def render_status_html(attempt)
        render_to_string(
          partial: "admin/settings/forms/test_digest_status",
          formats: [:html],
          locals: { attempt: attempt }
        )
      end
    end
  end
end
