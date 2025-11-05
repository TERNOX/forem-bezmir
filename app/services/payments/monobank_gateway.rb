module Payments
  class MonobankGateway < Gateway
    Customer = Struct.new(:id, :default_source, :sources, :subscriptions, keyword_init: true)
    Source = Struct.new(:id, :brand, :last4, :exp_month, :exp_year, :default, keyword_init: true)
    Subscription = Struct.new(:id, :status, :plan, :current_period_end, keyword_init: true)

    CHECKOUT_SESSION = Struct.new(:url, keyword_init: true)
    BILLING_PORTAL_SESSION = Struct.new(:url, keyword_init: true)

    def get(customer_id)
      data = request(:get, "/customers/#{customer_id}")
      build_customer(data)
    end

    def create(**params)
      data = request(:post, "/customers", body: params)
      build_customer(data)
    end

    def save(customer)
      body = { default_source: customer.default_source }
      request(:patch, "/customers/#{customer.id}", body: body)
      true
    end

    def create_source(customer_id, token)
      data = request(:post, "/customers/#{customer_id}/cards", body: { token: token })
      build_source(data)
    end

    def get_source(customer, source_id)
      customer_sources = fetch_sources_for(customer.id)
      source = customer_sources.find { |card| card.id == source_id }
      return source if source

      data = request(:get, "/customers/#{customer.id}/cards/#{source_id}")
      build_source(data)
    end

    def detach_source(customer_id, source_id)
      request(:delete, "/customers/#{customer_id}/cards/#{source_id}")
      true
    end

    def get_sources(customer, **_params)
      fetch_sources_for(customer.id)
    end

    def charge(customer:, amount:, description:, card_id: nil)
      body = {
        customer_id: customer.id,
        source_id: card_id || customer.default_source,
        amount: amount,
        description: description,
        currency: "uah",
      }
      request(:post, "/charges", body: body)
    end

    def create_subscription_session(user:, item_code:, mode:, success_url:, cancel_url:)
      body = {
        plan_code: item_code,
        mode: mode || "subscription",
        success_url: success_url,
        cancel_url: cancel_url,
        customer: {
          email: user.email,
          external_id: user.id,
        },
      }
      data = request(:post, "/checkout_sessions", body: body)
      CHECKOUT_SESSION.new(url: data.fetch("url"))
    end

    def create_billing_portal_session(customer_id:, return_url:)
      body = {
        customer_id: customer_id,
        return_url: return_url,
      }
      data = request(:post, "/billing_portal_sessions", body: body)
      BILLING_PORTAL_SESSION.new(url: data.fetch("url"))
    end

    def cancel_subscription(customer_id:, subscription_id: nil)
      id = subscription_id || active_subscription_id_for(customer_id)
      return unless id

      request(:post, "/subscriptions/#{id}/cancel")
      id
    end

    def supports_cards?
      true
    end

    def tokenize_card(number:, exp_month:, exp_year:, cvv:)
      body = {
        number: number,
        exp_month: exp_month,
        exp_year: exp_year,
        cvv: cvv,
        publishable_key: Settings::General.monobank_publishable_key,
      }.compact_blank

      data = request(:post, "/tokens", body: body)
      data.fetch("token")
    end

    private

    def build_customer(data)
      sources = Array.wrap(data["sources"]).map { |source| build_source(source) }
      subscriptions = Array.wrap(data["subscriptions"]).map { |sub| build_subscription(sub) }
      Customer.new(
        id: data.fetch("id"),
        default_source: data["default_source"],
        sources: SourcesCollection.new(self, data.fetch("id"), sources: sources),
        subscriptions: SubscriptionsCollection.new(subscriptions),
      )
    end

    def build_source(data)
      Source.new(
        id: data.fetch("id"),
        brand: data["brand"],
        last4: data["last4"],
        exp_month: data["exp_month"],
        exp_year: data["exp_year"],
        default: data["default"],
      )
    end

    def build_subscription(data)
      Subscription.new(
        id: data.fetch("id"),
        status: data["status"],
        plan: data["plan"],
        current_period_end: data["current_period_end"],
      )
    end

    def fetch_sources_for(customer_id)
      data = request(:get, "/customers/#{customer_id}/cards")
      Array.wrap(data).map { |source| build_source(source) }
    rescue InvalidRequestError
      []
    end

    def active_subscription_id_for(customer_id)
      data = request(:get, "/customers/#{customer_id}/subscriptions")
      active = Array.wrap(data).find { |sub| sub["status"] == "active" }
      active && active["id"]
    rescue InvalidRequestError
      nil
    end

    def request(method, path, body: nil)
      response = HTTParty.send(method, build_url(path), headers: headers(body), body: serialized_body(body))

      case response.code
      when 200..299
        parse_body(response.body)
      when 404
        raise InvalidRequestError, "Monobank resource not found"
      else
        Honeybadger.notify("Monobank request failed", context: { status: response.code, body: response.body })
        raise PaymentsError, "Monobank request failed with status #{response.code}"
      end
    rescue SocketError, Timeout::Error => e
      Honeybadger.notify(e)
      raise PaymentsError, e.message
    end

    def serialized_body(body)
      return if body.blank?

      body.to_json
    end

    def headers(body)
      headers = {
        "Authorization" => "Bearer #{Settings::General.monobank_api_key}",
        "Accept" => "application/json",
      }
      headers["Content-Type"] = "application/json" if body.present?
      headers
    end

    def build_url(path)
      base = Settings::General.monobank_base_url.presence || "https://api.monobank.ua"
      URI.join(base, path).to_s
    end

    def parse_body(body)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end

    class SourcesCollection
      include Enumerable

      def initialize(gateway, customer_id, sources: [])
        @gateway = gateway
        @customer_id = customer_id
        @sources = sources
      end

      def each(&block)
        list.each(&block)
      end

      def list(**_params)
        @sources = @gateway.fetch_sources_for(@customer_id)
      end

      def count
        list.count
      end

      def first
        list.first
      end

      def to_a
        list
      end

      def retrieve(source_id)
        source = list.find { |card| card.id == source_id }
        return source if source

        raise InvalidRequestError, "Card not found"
      end
    end

    class SubscriptionsCollection
      include Enumerable

      def initialize(subscriptions = [])
        @subscriptions = subscriptions
      end

      def each(&block)
        @subscriptions.each(&block)
      end

      def count
        @subscriptions.count
      end

      def first
        @subscriptions.first
      end
    end
  end
end
