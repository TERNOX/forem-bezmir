# CLDR plural rules for locales that need more than one/other.
# Loaded by I18n::Backend::Pluralization (see config/initializers/i18n_pluralization.rb).
{
  uk: {
    i18n: {
      plural: {
        keys: %i[one few many other],
        rule: lambda do |count|
          return :other unless count.is_a?(Integer) || (count.is_a?(Numeric) && count % 1 == 0)

          mod10 = count.to_i % 10
          mod100 = count.to_i % 100

          if mod10 == 1 && mod100 != 11
            :one
          elsif (2..4).cover?(mod10) && !(12..14).cover?(mod100)
            :few
          else
            :many
          end
        end
      }
    }
  }
}
