# Resolves the RSA key that signs OIDC id_tokens.
#
# Lives under config/ rather than app/lib on purpose: the doorkeeper
# initializer needs this at boot, and referencing an autoloaded constant from
# an initializer is not allowed — Zeitwerk has not taken over yet. Being
# outside the autoload paths lets the initializer `require_relative` it.
#
# The key is a multi-line PEM, and the places it has to be configured from
# usually cannot hold one: a Docker `--env-file`, a systemd `EnvironmentFile`
# and a Heroku-style config store all treat a value as a single line. Pasting
# a PEM into `rails.env` therefore produces a truncated key and a provider that
# fails at boot, which is a confusing way to learn about the limitation.
#
# So three sources are accepted, in this order:
#
#   OIDC_SIGNING_KEY_PATH    path to a PEM file on disk (preferred on a server
#                            you control: keep it 0600, out of the env file)
#   OIDC_SIGNING_KEY_BASE64  the PEM, base64-encoded into one line
#   OIDC_SIGNING_KEY         the PEM itself, for hosts that do support
#                            multi-line values
#
# With none of them set, a key is generated at boot. That keeps the forum up
# instead of taking it down over one unset variable, but signatures then stop
# verifying after a restart and differ between instances — so it warns loudly
# in production rather than failing silently.
module OidcSigningKey
  PATH_VAR = "OIDC_SIGNING_KEY_PATH".freeze
  BASE64_VAR = "OIDC_SIGNING_KEY_BASE64".freeze
  RAW_VAR = "OIDC_SIGNING_KEY".freeze

  module_function

  # @return [String] a PEM-encoded private key
  def resolve
    from_path || from_base64 || from_raw || generated
  end

  def from_path
    path = ENV[PATH_VAR].presence
    return if path.blank?

    unless File.readable?(path)
      raise "#{PATH_VAR} points at #{path}, which cannot be read"
    end

    File.read(path)
  end

  def from_base64
    encoded = ENV[BASE64_VAR].presence
    return if encoded.blank?

    # strict_decode64 rejects stray whitespace instead of quietly producing
    # garbage that only fails later, deep inside OpenSSL.
    Base64.strict_decode64(encoded.strip)
  rescue ArgumentError
    raise "#{BASE64_VAR} is not valid base64"
  end

  def from_raw
    ENV[RAW_VAR].presence
  end

  def generated
    if Rails.env.production?
      Rails.logger.warn(
        "[oidc] No signing key configured (#{PATH_VAR}, #{BASE64_VAR} or #{RAW_VAR}) — " \
        "signing id_tokens with an ephemeral key. Signatures will break on restart " \
        "and across instances.",
      )
    end

    OpenSSL::PKey::RSA.new(2048).to_pem
  end
end
