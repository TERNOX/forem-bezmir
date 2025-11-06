module Payments
  class StripeGateway < Gateway
    def initialize
      Stripe.api_key = Settings::General.stripe_api_key
      Stripe.log_level = Stripe::LEVEL_INFO if Rails.env.development? && Stripe.api_key.present?
    end

    def get(customer_id)
      request { Stripe::Customer.retrieve(customer_id) }
    end

    def create(**params)
      request { Stripe::Customer.create(**params) }
    end

    def save(customer)
      request { customer.save }
    end

    def create_source(customer_id, token)
      request { Stripe::Customer.create_source(customer_id, source: token) }
    end

    def get_source(customer, source_id)
      request { customer.sources.retrieve(source_id) }
    end

    def detach_source(customer_id, source_id)
      request { Stripe::Customer.detach_source(customer_id, source_id) }
    end

    def get_sources(customer, **params)
      request { customer.sources.list(**params) }
    end

    def charge(customer:, amount:, description:, card_id: nil)
      source = card_id || customer.default_source

      request do
        Stripe::Charge.create(
          customer: customer.id,
          source: source,
          amount: amount,
          description: description,
          currency: I18n.t("services.payments.customer.usd"),
        )
      end
    end

    def create_subscription_session(user:, item_code:, mode:, success_url:, cancel_url:)
      request do
        Stripe::Checkout::Session.create(
          line_items: [
            {
              price: item_code,
              quantity: 1,
            },
          ],
          mode: mode || "subscription",
          allow_promotion_codes: true,
          success_url: success_url,
          cancel_url: cancel_url,
          consent_collection: {
            terms_of_service: "required",
          },
          customer_email: user.email,
          metadata: {
            user_id: user.id,
          },
        )
      end
    end

    def create_billing_portal_session(customer_id:, return_url:)
      request do
        Stripe::BillingPortal::Session.create({
          customer: customer_id,
          return_url: return_url,
        })
      end
    end

    def cancel_subscription(customer_id:, subscription_id: nil)
      subscription = request do
        if subscription_id.present?
          Stripe::Subscription.retrieve(subscription_id)
        else
          Stripe::Subscription.list(customer: customer_id).data.first
        end
      end

      return unless subscription

      request do
        Stripe::Subscription.update(subscription.id, { cancel_at_period_end: false })
      end

      subscription.id
    end

    private

    def request
      yield
    rescue Stripe::InvalidRequestError => e
      ForemStatsClient.increment("stripe.errors", tags: ["error:InvalidRequestError"])
      raise InvalidRequestError, e.message
    rescue Stripe::CardError => e
      ForemStatsClient.increment("stripe.errors", tags: ["error:CardError"])
      raise CardError, e.message
    rescue Stripe::StripeError => e
      Honeybadger.notify(e)
      ForemStatsClient.increment("stripe.errors", tags: ["error:StripeError"])
      raise PaymentsError, e.message
    end
  end
end
