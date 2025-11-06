module Payments
  class Customer
    class << self
      delegate :get,
               :create,
               :save,
               :create_source,
               :get_source,
               :detach_source,
               :get_sources,
               :charge,
               to: :gateway

      private

      def gateway
        Payments::Gateway.build
      end
    end
  end
end
