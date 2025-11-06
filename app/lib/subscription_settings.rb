# frozen_string_literal: true

require "uri"

module SubscriptionSettings
  DEFAULT_PRODUCT_NAME = "DEV++".freeze
  DEFAULT_LANDING_PAGE_PATH = "/++".freeze
  DEFAULT_ICON_PROC = proc { URL.local_image("subscription-icon.png") }

  module_function

  def product_name
    Settings::General.subscription_product_name.presence || DEFAULT_PRODUCT_NAME
  end

  def landing_page_path
    Settings::General.subscription_landing_page_url.presence || DEFAULT_LANDING_PAGE_PATH
  end

  def landing_page_url
    path = landing_page_path
    return path if path =~ URI::DEFAULT_PARSER.make_regexp(%w[http https])

    URL.url(path)
  end

  def icon_url
    Settings::General.subscriber_icon_url.presence || DEFAULT_ICON_PROC.call
  end
end
