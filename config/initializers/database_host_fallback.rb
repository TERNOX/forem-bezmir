# Ensure database URLs do not rely on the "localhost" hostname, which may not resolve in some container runtimes.
# We rewrite any provided database URL hosts to a configurable fallback IP/hostname and
# also provide a PGHOST default for environments that omit a full URL.

require "uri"

fallback_host = ENV["DATABASE_HOST"].presence || ENV["DB_HOST"].presence || "127.0.0.1"
%w[NEW_DATABASE_URL DATABASE_URL].each do |var|
  url = ENV[var]
  next if url.blank?

  begin
    uri = URI.parse(url)
    next unless uri.host == "localhost"

    uri.host = fallback_host
    ENV[var] = uri.to_s
  rescue URI::InvalidURIError
    # Ignore malformed URLs and leave them untouched.
  end
end

ENV["PGHOST"] ||= fallback_host
