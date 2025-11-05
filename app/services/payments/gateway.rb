module Payments
  class Gateway
    UnsupportedProviderError = Class.new(PaymentsError)

    PROVIDERS = {
      stripe: "Payments::StripeGateway",
      monobank: "Payments::MonobankGateway"
    }.freeze

    class << self
      def build(provider: default_provider)
        provider_key = provider.to_sym
        klass_name = PROVIDERS.fetch(provider_key) do
          raise UnsupportedProviderError, "Unsupported payments provider: #{provider}"
        end

        @instances ||= {}
        @instances[provider_key] ||= klass_name.constantize.new
      end

      def reset!
        @instances = {}
      end

      def default_provider
        Settings::General.payment_provider.presence&.to_sym || :stripe
      rescue NoMethodError
        :stripe
      end
    end

    def get(_customer_id)
      raise NotImplementedError, "#get must be implemented in subclasses"
    end

    def create(**_params)
      raise NotImplementedError, "#create must be implemented in subclasses"
    end

    def save(_customer)
      raise NotImplementedError, "#save must be implemented in subclasses"
    end

    def create_source(_customer_id, _token)
      raise NotImplementedError, "#create_source must be implemented in subclasses"
    end

    def get_source(_customer, _source_id)
      raise NotImplementedError, "#get_source must be implemented in subclasses"
    end

    def detach_source(_customer_id, _source_id)
      raise NotImplementedError, "#detach_source must be implemented in subclasses"
    end

    def get_sources(_customer, **_params)
      raise NotImplementedError, "#get_sources must be implemented in subclasses"
    end

    def charge(customer:, amount:, description:, card_id: nil)
      raise NotImplementedError, "#charge must be implemented in subclasses"
    end

    def create_subscription_session(**_options)
      raise NotImplementedError, "#create_subscription_session must be implemented in subclasses"
    end

    def create_billing_portal_session(**_options)
      raise NotImplementedError, "#create_billing_portal_session must be implemented in subclasses"
    end

    def cancel_subscription(**_options)
      raise NotImplementedError, "#cancel_subscription must be implemented in subclasses"
    end

    def supports_cards?
      true
    end

    def tokenize_card(**_card_details)
      raise NotImplementedError, "#tokenize_card must be implemented in subclasses"
    end
  end
end
