require "rails_helper"

# This Forem instance acts as an OpenID Connect provider so a federated site can
# offer "sign in with this community". The relying party discovers every
# endpoint through the discovery document, exchanges an authorization code for a
# token, and reads the claims from userinfo — so those three steps are what
# these specs cover, plus the guards that keep the flow honest.
RSpec.describe "OpenID Connect provider" do
  let(:user) { create(:user) }

  let(:application) do
    Doorkeeper::Application.create!(
      name: "Federated site",
      redirect_uri: "https://example.test/auth/callback",
      scopes: "openid email profile",
      confidential: true,
    )
  end

  describe "discovery" do
    it "publishes the endpoints a relying party needs" do
      get "/.well-known/openid-configuration"

      expect(response).to have_http_status(:ok)

      document = response.parsed_body

      expect(document["issuer"]).to eq(URL.url)
      expect(document["authorization_endpoint"]).to end_with("/oauth/authorize")
      expect(document["token_endpoint"]).to end_with("/oauth/token")
      expect(document["userinfo_endpoint"]).to end_with("/oauth/userinfo")
      expect(document["scopes_supported"]).to include("openid", "email", "profile")
    end

    it "publishes a signing key so id_tokens can be verified" do
      get "/oauth/discovery/keys"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["keys"].first["kty"]).to eq("RSA")
    end
  end

  describe "authorization" do
    it "sends an anonymous visitor to sign in instead of leaking a code" do
      get "/oauth/authorize", params: {
        client_id: application.uid,
        redirect_uri: application.redirect_uri,
        response_type: "code",
        scope: "openid email"
      }

      expect(response).to have_http_status(:redirect)
      expect(response.redirect_url).to include("/enter").or include("/users/sign_in")
    end

    it "issues a code to a signed-in user who approves" do
      sign_in user

      post "/oauth/authorize", params: {
        client_id: application.uid,
        redirect_uri: application.redirect_uri,
        response_type: "code",
        scope: "openid email profile"
      }

      expect(response).to have_http_status(:redirect)
      expect(response.redirect_url).to start_with(application.redirect_uri)
      expect(Doorkeeper::AccessGrant.last.resource_owner_id).to eq(user.id)
    end

    it "refuses a scope the application was not granted" do
      sign_in user

      post "/oauth/authorize", params: {
        client_id: application.uid,
        redirect_uri: application.redirect_uri,
        response_type: "code",
        scope: "openid admin"
      }

      expect(response.redirect_url).to include("error=invalid_scope")
      expect(Doorkeeper::AccessGrant.count).to be_zero
    end
  end

  describe "token exchange and claims" do
    def authorization_code_for(scope: "openid email profile")
      sign_in user

      post "/oauth/authorize", params: {
        client_id: application.uid,
        redirect_uri: application.redirect_uri,
        response_type: "code",
        scope: scope
      }

      CGI.parse(URI.parse(response.redirect_url).query)["code"].first
    end

    def access_token_for(code)
      post "/oauth/token", params: {
        grant_type: "authorization_code",
        code: code,
        client_id: application.uid,
        client_secret: application.plaintext_secret,
        redirect_uri: application.redirect_uri
      }

      response.parsed_body["access_token"]
    end

    it "exchanges the code for a token and returns the profile claims" do
      token = access_token_for(authorization_code_for)

      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)

      claims = response.parsed_body

      expect(claims["sub"]).to eq(user.id.to_s)
      expect(claims["email"]).to eq(user.email)
      expect(claims["preferred_username"]).to eq(user.username)
      expect(claims["name"]).to eq(user.name)
    end

    # The federated site may only merge accounts when both sides confirmed the
    # same address, so this claim has to mirror Devise's confirmable exactly —
    # a hardcoded `true` here would let anyone take over an account by signing
    # up on this side with someone else's address.
    it "reports email_verified for a confirmed account" do
      user.update!(confirmed_at: Time.current)

      token = access_token_for(authorization_code_for)
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      expect(response.parsed_body["email_verified"]).to be(true)
    end

    it "reports email_verified as false while the address is unconfirmed" do
      user.update_columns(confirmed_at: nil)

      token = access_token_for(authorization_code_for)
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      expect(response.parsed_body["email_verified"]).to be(false)
    end

    it "withholds email claims when the email scope was not requested" do
      token = access_token_for(authorization_code_for(scope: "openid profile"))

      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      claims = response.parsed_body

      expect(claims).to have_key("sub")
      expect(claims).not_to have_key("email")
      expect(claims).not_to have_key("email_verified")
    end

    it "rejects a request without a token" do
      get "/oauth/userinfo"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "client guards" do
    it "refuses a public client — it cannot keep a secret" do
      public_app = Doorkeeper::Application.create!(
        name: "Public client",
        redirect_uri: "https://example.test/auth/callback",
        scopes: "openid email",
        confidential: false,
      )

      sign_in user

      post "/oauth/authorize", params: {
        client_id: public_app.uid,
        redirect_uri: public_app.redirect_uri,
        response_type: "code",
        scope: "openid email"
      }

      # doorkeeper renders its error page here rather than bouncing back to
      # the client; what matters is that no grant is handed out and no code
      # ever reaches the redirect URI.
      expect(response.redirect_url.to_s).not_to include("code=")
      expect(Doorkeeper::AccessGrant.count).to be_zero
    end
  end
end
