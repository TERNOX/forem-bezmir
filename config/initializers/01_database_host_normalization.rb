# Normalize database URLs so they never rely on DNS for "localhost".
# In some environments (e.g. minimal containers), the hostname may not
# be present in /etc/hosts, leading to PG::ConnectionBad: could not
# translate host name "localhost" to address.
# Converting "localhost" to 127.0.0.1 keeps the connection local while
# avoiding the DNS lookup entirely.

require "uri"

%w[NEW_DATABASE_URL DATABASE_URL].each do |env_key|
  raw = ENV[env_key]
  next if raw.blank?

  begin
    uri = URI.parse(raw)
  rescue URI::InvalidURIError
    next
  end

  next unless uri.hostname == "localhost"

  uri.hostname = "127.0.0.1"
  ENV[env_key] = uri.to_s
end
