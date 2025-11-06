module IncomingWebhooks
  class MonobankEventsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :ensure_monobank_provider

    def create
      payload = request.body.read
      signature = request.env["HTTP_X_MONOBANK_SIGNATURE"]

      unless valid_signature?(payload, signature)
        Rails.logger.error "Monobank signature mismatch"
        render json: { error: "Invalid signature" }, status: :bad_request and return
      end

      event = JSON.parse(payload)
      Rails.logger.info "Monobank event received: #{event.inspect}"

      case event["type"]
      when "subscription.active"
        handle_subscription_active(event["data"])
      when "subscription.updated"
        handle_subscription_updated(event["data"])
      when "subscription.cancelled"
        handle_subscription_cancelled(event["data"])
      else
        Rails.logger.info "Unhandled Monobank event type: #{event['type']}"
      end

      render json: { status: "success" }, status: :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Monobank payload parse error: #{e.message}"
      render json: { error: "Invalid payload (#{e.message})" }, status: :bad_request
    end

    private

    def ensure_monobank_provider
      head :not_found unless Payments::Gateway.default_provider == :monobank
    end

    def valid_signature?(payload, signature)
      secret = Settings::General.monobank_webhook_secret
      return false if secret.blank? || signature.blank?

      computed = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(computed, signature)
    end

    def handle_subscription_active(data)
      metadata = data.fetch("metadata", {})
      user_id = metadata["user_id"]
      return unless user_id

      user = User.find_by(id: user_id)
      return unless user

      customer_id = data["customer_id"]
      subscription_id = data["subscription_id"]

      user.add_role("base_subscriber") unless user.base_subscriber?
      user.update(
        monobank_customer_id: customer_id,
        monobank_subscription_id: subscription_id,
      )
      user.profile&.touch
      NotifyMailer.with(user: user).base_subscriber_role_email.deliver_now

      create_conversion_events_for(user)
    end

    def handle_subscription_updated(data)
      metadata = data.fetch("metadata", {})
      user_id = metadata["user_id"]
      return unless user_id

      user = User.find_by(id: user_id)
      return unless user

      if data["status"] == "cancelling"
        user.add_role("impending_base_subscriber_cancellation") unless user.impending_base_subscriber_cancellation?
      else
        user.add_role("base_subscriber") unless user.base_subscriber?
      end

      if data["subscription_id"].present?
        user.update(monobank_subscription_id: data["subscription_id"])
      end
    end

    def handle_subscription_cancelled(data)
      metadata = data.fetch("metadata", {})
      user_id = metadata["user_id"]
      return unless user_id

      user = User.find_by(id: user_id)
      return unless user

      user.add_role("impending_base_subscriber_cancellation") unless user.impending_base_subscriber_cancellation?
    end

    def create_conversion_events_for(user)
      last_billboard_events = BillboardEvent
        .where(user_id: user.id, category: "click")
        .where("created_at > ?", 3.hours.ago)
        .order("created_at DESC").limit(3)
      return unless last_billboard_events.any?

      last_billboard_events.each do |event|
        BillboardEvent.create(user_id: user.id,
                              category: "conversion",
                              geolocation: event.geolocation,
                              context_type: event.context_type,
                              billboard_id: event.billboard_id)
      end
    end
  end
end
