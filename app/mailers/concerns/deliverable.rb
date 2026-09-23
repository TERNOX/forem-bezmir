module Deliverable
  extend ActiveSupport::Concern

  included do
    before_action :set_perform_deliveries
    after_action  :set_delivery_options
    before_deliver :apply_delivery_switch
  end

  def set_perform_deliveries
    self.perform_deliveries = ForemInstance.smtp_enabled?
  end

  def set_delivery_options
    mail.delivery_method.settings.merge!(Settings::SMTP.settings)
  end

  def apply_delivery_switch
    mail.perform_deliveries = false unless Settings::SMTP.delivery_enabled
  end
end
