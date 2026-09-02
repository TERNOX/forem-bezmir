# OpenID Connect layer on top of doorkeeper.
#
# Relying parties discover every endpoint through
# /.well-known/openid-configuration, so nothing here is hardcoded on their
# side: changing a path in this app does not break their sign-in.
require_relative "../oidc_signing_key"

Doorkeeper::OpenidConnect.configure do
  issuer do |_resource_owner, _application|
    URL.url
  end

  # RSA key used to sign id_tokens, and published through JWKS.
  #
  # Accepts a file path, a base64 one-liner or the PEM itself — see
  # OidcSigningKey for why a plain multi-line variable is not enough.
  signing_key OidcSigningKey.resolve

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    resource_owner.current_sign_in_at || resource_owner.created_at
  end

  reauthenticate_resource_owner do |_resource_owner, return_to|
    store_location_for(:user, return_to)
    sign_out
    redirect_to(new_user_session_url)
  end

  # The stable identifier a relying party stores. The database id never
  # changes, unlike the username, which people edit.
  subject do |resource_owner, _application|
    resource_owner.id
  end

  claims do
    # Both block parameters are declared on purpose: doorkeeper calls these
    # with (resource_owner, scopes), and a single-parameter block invites
    # rubocop's Style/SymbolProc to rewrite it as `&:email` — which then blows
    # up at runtime with "wrong number of arguments". Lint-clean and broken.
    #
    # `email_verified` is the claim federated sign-in leans on: a relying party
    # may only merge accounts when both sides confirmed the same address.
    # Devise's confirmable is the single source of truth for that here.
    claim :email, scope: :email do |resource_owner, _scopes|
      resource_owner.email
    end

    claim :email_verified, scope: :email do |resource_owner, _scopes|
      resource_owner.confirmed_at.present?
    end

    claim :name, scope: :profile do |resource_owner, _scopes|
      resource_owner.name
    end

    claim :preferred_username, scope: :profile do |resource_owner, _scopes|
      resource_owner.username
    end

    claim :picture, scope: :profile do |resource_owner, _scopes|
      resource_owner.profile_image_url
    end

    claim :profile, scope: :profile do |resource_owner, _scopes|
      URL.url(resource_owner.path)
    end
  end
end
