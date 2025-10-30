Rails.application.config.to_prepare do
  Settings::UserExperience.apply_default_locale! if Settings::UserExperience.respond_to?(:apply_default_locale!)
end
