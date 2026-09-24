class EmailSubscriptionsController < ApplicationController
  # RFC 8058 one-click unsubscribe requests are POSTed by the mailbox provider
  # (Gmail, Yahoo, ...) and cannot carry a CSRF token. The signed `ut` token is
  # what authenticates the request.
  skip_before_action :verify_authenticity_token, only: %i[unsubscribe]

  def unsubscribe
    return not_found unless params[:ut].is_a?(String)

    verified_params = Rails.application.message_verifier(:unsubscribe).verify(params[:ut])
    return render "invalid_token" unless verified_params.is_a?(Hash)

    verified_params = verified_params.with_indifferent_access
    expires_at = unsubscribe_expiration(verified_params[:expires_at])
    email_type = verified_params[:email_type].to_s
    email_name = preferred_email_name[email_type.to_sym]
    user_id = verified_params[:user_id]

    unless expires_at && expires_at > Time.current && email_name && user_id.to_s.match?(/\A[1-9]\d*\z/)
      return render "invalid_token"
    end

    user = User.find(user_id)
    user.notification_setting.update!(email_type => false)
    @email_type = email_name.call
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    not_found
  end

  private

  # JSON returns string keys and ISO 8601 timestamps; older Marshal tokens
  # can contain symbol keys and Time/TimeWithZone values.
  def unsubscribe_expiration(value)
    case value
    when String
      Time.iso8601(value)
    when Time, DateTime, ActiveSupport::TimeWithZone
      value.to_time
    end
  rescue ArgumentError
    nil
  end

  def preferred_email_name
    {
      email_digest_periodic: lambda {
                               I18n.t("email_subscriptions_controller.digest_emails",
                                      community: Settings::Community.community_name)
                             },
      email_comment_notifications: -> { I18n.t("email_subscriptions_controller.comment_notifications") },
      email_follower_notifications: -> { I18n.t("email_subscriptions_controller.follower_notifications") },
      email_mention_notifications: -> { I18n.t("email_subscriptions_controller.mention_notifications") },
      email_unread_notifications: -> { I18n.t("email_subscriptions_controller.unread_notifications") },
      email_badge_notifications: -> { I18n.t("email_subscriptions_controller.badge_notifications") },
      email_newsletter: -> { I18n.t("email_subscriptions_controller.newsletter") }
    }.freeze
  end
end
