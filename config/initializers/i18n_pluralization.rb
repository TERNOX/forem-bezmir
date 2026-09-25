# Ukrainian needs the one/few/many plural forms. rails-i18n, which ships these rules, is only
# pulled in by the development-only i18n-tasks gem, so production would otherwise fall back to
# one/other. The rules themselves live in config/locales/plurals.rb.
require "i18n/backend/pluralization"

I18n::Backend::Simple.include(I18n::Backend::Pluralization)

# Locales without a rule (en, fr, pt) keep the default one/other behavior instead of raising
# under raise_on_missing_translations or trying to call a "translation missing" string.
module I18nPluralizationDefaultRule
  def pluralizer(locale)
    pluralizers[locale] ||=
      if I18n.exists?(:"i18n.plural.rule", locale)
        I18n.t(:"i18n.plural.rule", locale: locale, resolve: false)
      else
        :default
      end
  end
end

I18n::Backend::Simple.prepend(I18nPluralizationDefaultRule)
