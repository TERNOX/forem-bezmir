# OAuth 2 / OpenID Connect provider.
#
# This Forem instance can act as an identity provider so a federated site can
# offer "sign in with this community". Only the authorization code flow is
# enabled: every relying party here is a server-side application that keeps a
# client secret, so implicit and password flows would widen the attack surface
# without buying anything.
#
# doorkeeper lived in this codebase before and was removed upstream in 2021
# (20211222040359_remove_doorkeeper); this configuration is written against
# doorkeeper 5.9 rather than restored from that era.
Doorkeeper.configure do
  orm :active_record

  # Reuse the application controller so the consent screen inherits the site
  # layout, locale resolution, CSRF protection and the private-forem guard.
  # Without it the authorization page renders outside the app shell and skips
  # `verify_private_forem`.
  base_controller "ApplicationController"

  # Devise owns the session. `warden.authenticate!` bounces an anonymous
  # visitor to the sign-in page and returns them here afterwards, which is what
  # a person expects when they click "sign in with this community" while
  # logged out.
  resource_owner_authenticator do
    current_user || warden.authenticate!(scope: :user)
  end

  # Doorkeeper's built-in application CRUD lives under /oauth/applications.
  # Anything short of super admin there would hand out the ability to mint
  # identity clients for this community.
  admin_authenticator do |_routes|
    if current_user&.super_admin?
      true
    else
      redirect_to("/", alert: I18n.t("doorkeeper.admin.not_authorized"))
    end
  end

  # Authorization codes are exchanged for a token within seconds of the
  # redirect, so they stay short-lived by design.
  authorization_code_expires_in 10.minutes

  # A token is used to read the userinfo endpoint once, right after login.
  # A short life makes a leaked token nearly worthless, and nothing needs
  # long-lived access, so there is no refresh token.
  access_token_expires_in 30.minutes

  # `openid` turns the request into an OIDC one; `email` and `profile` carry
  # the claims a relying party needs to create an account.
  default_scopes  :openid
  optional_scopes :email, :profile

  # A client may only ask for the scopes listed above.
  enforce_configured_scopes

  grant_flows %w[authorization_code]

  # Confidential clients only: a public client cannot keep a secret.
  allow_grant_flow_for_client do |_grant_flow, client|
    client.confidential?
  end

  # A plain HTTP redirect URI is a downgrade path for the authorization code;
  # allow it only in development, where there is no TLS.
  force_ssl_in_redirect_uri !Rails.env.development?
end
