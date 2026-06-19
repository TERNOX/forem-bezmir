Rails.application.config.to_prepare do
  # Apply the community's configured default locale (defaults to "uk") in real
  # environments. Skip in test so the suite runs under Rails' default :en,
  # matching upstream specs that assert English copy/error messages. Specs that
  # exercise locale syncing call apply_default_locale! explicitly, so they are
  # unaffected. Production/development behaviour is unchanged.
  next if Rails.env.test?

  Settings::UserExperience.apply_default_locale! if Settings::UserExperience.respond_to?(:apply_default_locale!)
end
