require "rails_helper"

RSpec.describe Payments::MonobankGateway do
  subject(:gateway) { described_class.new }

  let(:base_url) { "https://monobank.example.com" }
  let(:api_key) { "test-api" }

  before do
    allow(Settings::General).to receive(:monobank_base_url).and_return(base_url)
    allow(Settings::General).to receive(:monobank_api_key).and_return(api_key)
    allow(Settings::General).to receive(:monobank_webhook_secret).and_return("secret")
  end

  describe "customer management" do
    let(:customer_response) do
      instance_double(HTTParty::Response, code: 200, body: {
        id: "cust_123",
        default_source: "card_123",
        sources: [
          { id: "card_123", brand: "visa", last4: "4242" }
        ],
        subscriptions: [
          { id: "sub_123", status: "active" }
        ],
      }.to_json)
    end

    it "creates a customer" do
      expect(HTTParty).to receive(:post)
        .with("#{base_url}/customers", anything)
        .and_return(customer_response)

      customer = gateway.create(email: "user@example.com")
      expect(customer.id).to eq("cust_123")
      expect(customer.sources.list.count).to eq(1)
    end

    it "retrieves a customer" do
      expect(HTTParty).to receive(:get)
        .with("#{base_url}/customers/cust_123", anything)
        .and_return(customer_response)

      customer = gateway.get("cust_123")
      expect(customer.id).to eq("cust_123")
    end

    it "raises an error when the customer is missing" do
      missing_response = instance_double(HTTParty::Response, code: 404, body: "not found")
      expect(HTTParty).to receive(:get).and_return(missing_response)

      expect { gateway.get("missing") }.to raise_error(Payments::InvalidRequestError)
    end
  end

  describe "subscription sessions" do
    let(:session_response) do
      instance_double(HTTParty::Response, code: 200, body: { url: "https://pay.example.com/session" }.to_json)
    end

    it "creates a checkout session" do
      expect(HTTParty).to receive(:post)
        .with("#{base_url}/checkout_sessions", anything)
        .and_return(session_response)

      session = gateway.create_subscription_session(
        user: build(:user),
        item_code: "plan_123",
        mode: "subscription",
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel",
      )

      expect(session.url).to eq("https://pay.example.com/session")
    end

    it "creates a billing portal session" do
      expect(HTTParty).to receive(:post)
        .with("#{base_url}/billing_portal_sessions", anything)
        .and_return(session_response)

      session = gateway.create_billing_portal_session(customer_id: "cust_123", return_url: "https://example.com")
      expect(session.url).to eq("https://pay.example.com/session")
    end
  end

  describe "cancel_subscription" do
    let(:subscriptions_response) do
      instance_double(HTTParty::Response, code: 200, body: [
        { "id" => "sub_123", "status" => "active" }
      ].to_json)
    end

    it "cancels using an explicit subscription id" do
      allow(HTTParty).to receive(:post).with("#{base_url}/subscriptions/sub_123/cancel", anything)
        .and_return(instance_double(HTTParty::Response, code: 200, body: {}.to_json))

      expect(gateway.cancel_subscription(customer_id: "cust_123", subscription_id: "sub_123")).to eq("sub_123")
    end

    it "cancels the first active subscription when no id is provided" do
      allow(HTTParty).to receive(:get)
        .with("#{base_url}/customers/cust_123/subscriptions", anything)
        .and_return(subscriptions_response)

      allow(HTTParty).to receive(:post)
        .with("#{base_url}/subscriptions/sub_123/cancel", anything)
        .and_return(instance_double(HTTParty::Response, code: 200, body: {}.to_json))

      expect(gateway.cancel_subscription(customer_id: "cust_123")).to eq("sub_123")
    end

    it "returns nil when no active subscription exists" do
      empty_response = instance_double(HTTParty::Response, code: 200, body: [].to_json)
      allow(HTTParty).to receive(:get).and_return(empty_response)

      expect(gateway.cancel_subscription(customer_id: "cust_123")).to be_nil
    end
  end
end
