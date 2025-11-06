class MonobankTokensController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_monobank_provider

  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  def create
    token = monobank_gateway.tokenize_card(card_params.to_h.symbolize_keys)
    render json: { token: token }
  rescue Payments::PaymentsError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def card_params
    params.require(:card).permit(:number, :exp_month, :exp_year, :cvv)
  end

  def monobank_gateway
    @monobank_gateway ||= Payments::Gateway.build(provider: :monobank)
  end

  def ensure_monobank_provider
    head :not_found unless Payments::Gateway.default_provider == :monobank
  end

  def render_bad_request
    render json: { error: I18n.t("services.payments.errors.select_payment_method") }, status: :unprocessable_entity
  end
end
