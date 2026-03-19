# frozen_string_literal: true

# Provides the full allowlist of domains that should be treated as internal
# links throughout Liquid processing.
module InternalLinkDomains
  module_function

  def allowlist
    domains = subforem_domains + configured_domains + additional_domains

    domains.each_with_object([]) do |domain, list|
      next if domain.blank?

      list << domain.downcase
    end.uniq
  end

  def subforem_domains
    Subforem.cached_domains
  end

  def configured_domains
    secondary_domains = ApplicationConfig["SECONDARY_APP_DOMAINS"].to_s.split(",").map(&:strip)
    [Settings::General.app_domain] + secondary_domains
  end

  def additional_domains
    %w[kutok.io]
  end
end
