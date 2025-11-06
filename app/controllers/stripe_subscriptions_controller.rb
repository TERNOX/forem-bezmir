class StripeSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def new
    item_code = if ENV.fetch("STRIPE_TAG_MODERATOR_ITEM_CODE", nil).present? && current_user&.tag_moderator?
                  ENV.fetch("STRIPE_TAG_MODERATOR_ITEM_CODE", nil)
                elsif params[:item].present? && params[:item] != ENV.fetch("STRIPE_TAG_MODERATOR_ITEM_CODE", nil)
                  params[:item]
                else
                  ENV.fetch("STRIPE_BASE_ITEM_CODE", nil)
                end

    session = payment_gateway.create_subscription_session(
      user: current_user,
      item_code: item_code,
      mode: params[:mode],
      success_url: URL.url(ENV["SUBSCRIPTION_SUCCESS_URL"] || "/settings/billing"),
      cancel_url: URL.url(ENV["SUBSCRIPTION_CANCEL_URL"] || "/settings/billing"),
    )
    redirect_to session.url, allow_other_host: true
  end

  def edit
    identifier = customer_identifier_for(current_user)

    if identifier.present?
      portal_session = payment_gateway.create_billing_portal_session(
        customer_id: identifier,
        return_url: URL.url(ENV["SUBSCRIPTION_CANCEL_URL"] || "/settings/billing"),
      )

      redirect_to portal_session.url, allow_other_host: true
    else
      flash[:error] = "Unable to edit subscription self-serve. Please contact support."
      redirect_back(fallback_location: user_settings_path)
    end
  end

  def destroy
    identifier = customer_identifier_for(current_user)
    subscription_id = subscription_identifier_for(current_user)

    if params[:verification] == "pleasecancelmyplusplus" && identifier.present?
      cancelled_id = payment_gateway.cancel_subscription(
        customer_id: identifier,
        subscription_id: subscription_id,
      )

      if cancelled_id.present?
        current_user.remove_role("base_subscriber")
        current_user.touch
        current_user.profile&.touch
        update_subscription_identifier(current_user, nil)
        flash[:notice] = "Your subscription has been canceled."
      else
        flash[:error] = "No active subscription found."
      end
    elsif identifier.present?
      flash[:error] = "Invalid verification parameter. Subscription was not canceled."
    else
      flash[:error] = "No active subscription found. Please contact us if you believe this is an error."
    end

    redirect_back(fallback_location: user_settings_path)
  end

  private

  def payment_gateway
    @payment_gateway ||= Payments::Gateway.build
  end

  def customer_identifier_for(user)
    user.public_send(customer_id_attribute)
  end

  def subscription_identifier_for(user)
    attribute = subscription_id_attribute
    attribute ? user.public_send(attribute) : nil
  end

  def customer_id_attribute
    @customer_id_attribute ||= payment_gateway.is_a?(Payments::MonobankGateway) ? :monobank_customer_id : :stripe_id_code
  end

  def subscription_id_attribute
    payment_gateway.is_a?(Payments::MonobankGateway) ? :monobank_subscription_id : nil
  end

  def update_subscription_identifier(user, value)
    attribute = subscription_id_attribute
    return unless attribute

    user.update(attribute => value)
  end
end
