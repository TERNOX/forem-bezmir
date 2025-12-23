ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Normalize database host usage before any framework code runs so tasks like
# `db:prepare` and initializers don't attempt to connect to an unreachable
# `localhost` host in containerized environments.
begin
  require "uri"

  fallback_host = ENV["DATABASE_HOST"]
  fallback_host = ENV["DB_HOST"] if fallback_host.nil? || fallback_host.empty?
  fallback_host = "127.0.0.1" if fallback_host.nil? || fallback_host.empty?

  %w[NEW_DATABASE_URL DATABASE_URL].each do |var|
    raw_url = ENV[var]
    next if raw_url.nil? || raw_url.empty?

    uri = URI.parse(raw_url)
    next unless uri.host == "localhost"

    uri.host = fallback_host
    ENV[var] = uri.to_s
  rescue URI::InvalidURIError
    # Leave malformed URLs untouched so they can surface meaningful errors later.
  end

  ENV["PGHOST"] ||= fallback_host

  redis_fallback_host = ENV["REDIS_HOST"]
  redis_fallback_host = fallback_host if redis_fallback_host.nil? || redis_fallback_host.empty?
  redis_fallback_host = "127.0.0.1" if redis_fallback_host.nil? || redis_fallback_host.empty?

  %w[REDISCLOUD_URL REDIS_URL REDIS_SIDEKIQ_URL REDIS_SESSIONS_URL REDIS_RPUSH_URL].each do |var|
    raw_url = ENV[var]

    if raw_url.nil? || raw_url.empty?
      next unless var == "REDIS_URL"

      ENV[var] = "redis://#{redis_fallback_host}:6379/0"
      next
    end

    uri = URI.parse(raw_url)
    next unless uri.host == "localhost"

    uri.host = redis_fallback_host
    ENV[var] = uri.to_s
  rescue URI::InvalidURIError
    # Leave malformed URLs untouched so they can surface meaningful errors later.
  end

  %w[REDIS_SIDEKIQ_URL REDIS_SESSIONS_URL REDIS_RPUSH_URL].each do |var|
    next unless ENV[var].nil? || ENV[var].empty?

    ENV[var] = ENV["REDIS_URL"]
  end
rescue LoadError
  # If URI isn't available for some reason, continue boot without rewrites.
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
