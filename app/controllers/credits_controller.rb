class CreditsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user_unspent_credits_count = current_user.credits.unspent.size
    @ledger = Credits::Ledger.call(current_user)

    @organizations = current_user.admin_organizations
  end

  def new
    @credit = Credit.new
    @purchaser = if params[:organization_id].present? && current_user.org_admin?(params[:organization_id])
                   Organization.find_by(id: params[:organization_id])
                 else
                   current_user
                 end
    @organizations = current_user.admin_organizations
    customer_id = customer_identifier_for(current_user)
    @customer = Payments::Customer.get(customer_id) if customer_id.present?
  end

  def create
    not_authorized if params[:organization_id].present? && !current_user.org_admin?(params[:organization_id])

    number_to_purchase = params[:credit][:number_to_purchase].to_i

    payment = Payments::ProcessCreditPurchase.call(
      current_user,
      number_to_purchase,
      purchase_options: params.slice(:stripe_token, :payment_token, :selected_card, :organization_id),
    )

    if payment.success?
      @purchaser = payment.purchaser
      redirect_to credits_path, notice: I18n.t("credits_controller.done", count: number_to_purchase)
    else
      flash[:error] = payment.error
      redirect_to purchase_credits_path
end

  private

  def payment_gateway
    @payment_gateway ||= Payments::Gateway.build
  end

  def customer_identifier_for(user)
    attribute = payment_gateway.is_a?(Payments::MonobankGateway) ? :monobank_customer_id : :stripe_id_code
    user.public_send(attribute)
  end
end
end
