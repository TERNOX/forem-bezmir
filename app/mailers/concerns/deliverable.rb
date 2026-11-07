module Deliverable
  extend ActiveSupport::Concern

  included do
    before_action :set_perform_deliveries
    after_action  :set_delivery_options
  end

  def set_perform_deliveries
    self.perform_deliveries = ForemInstance.smtp_enabled?
  end

  def set_delivery_options
    # A mailer action may decline to send by returning before mail(); Rails then
    # swaps in a NullMail. Calling mail() here would instead build the message the
    # action deliberately skipped, with no recipient.
    return unless @_mail_was_called

    mail.delivery_method.settings.merge!(Settings::SMTP.settings)
  end
end
