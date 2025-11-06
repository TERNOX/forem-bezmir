require "rails_helper"

RSpec.describe "IncomingWebhooks::MonobankEventsController" do
  let(:secret) { "monobank-secret" }
  let(:user) { create(:user) }

  before do
    allow(Settings::General).to receive(:payment_provider).and_return("monobank")
    allow(Settings::General).to receive(:monobank_webhook_secret).and_return(secret)
    allow(NotifyMailer).to receive_message_chain(:with, :base_subscriber_role_email, :deliver_now)
    Payments::Gateway.reset!
  end

  after { Payments::Gateway.reset! }

  def signature_for(payload)
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  describe "POST /incoming_webhooks/monobank_events" do
    let(:headers) { { "HTTP_X_MONOBANK_SIGNATURE" => signature_for(payload) } }

    context "when the event activates a subscription" do
      let(:payload) do
        {
          type: "subscription.active",
          data: {
            metadata: { "user_id" => user.id },
            customer_id: "cust_123",
            subscription_id: "sub_123"
          }
        }.to_json
      end

      it "stores monobank identifiers and grants the role" do
        expect do
          post incoming_webhooks_monobank_events_path, params: payload, headers: headers
        end.to change { user.reload.monobank_customer_id }.to("cust_123")

        expect(user.reload.monobank_subscription_id).to eq("sub_123")
        expect(user.reload).to be_base_subscriber
        expect(NotifyMailer).to have_received(:with).with(user: user)
      end
    end

    context "when the event updates a subscription" do
      let(:payload) do
        {
          type: "subscription.updated",
          data: {
            metadata: { "user_id" => user.id },
            status: "cancelling",
            subscription_id: "sub_123"
          }
        }.to_json
      end

      it "marks the subscription for cancellation" do
        post incoming_webhooks_monobank_events_path, params: payload, headers: headers

        expect(user.reload).to be_impending_base_subscriber_cancellation
        expect(user.reload.monobank_subscription_id).to eq("sub_123")
      end
    end

    context "when the signature is invalid" do
      let(:payload) { { type: "subscription.active", data: {} }.to_json }
      let(:headers) { { "HTTP_X_MONOBANK_SIGNATURE" => "invalid" } }

      it "returns a bad request" do
        post incoming_webhooks_monobank_events_path, params: payload, headers: headers
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the provider is not monobank" do
      before { allow(Settings::General).to receive(:payment_provider).and_return("stripe") }

      let(:payload) { { type: "subscription.active", data: {} }.to_json }

      it "returns not found" do
        post incoming_webhooks_monobank_events_path, params: payload, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
