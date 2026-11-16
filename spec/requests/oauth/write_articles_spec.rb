require "rails_helper"

# A federated site (Новельня) can publish a member's devlog as an article here
# after the member grants it the `write_articles` scope. The token is accepted
# only by the article create/update endpoints, only with that scope, and only
# for applications an admin granted the scope to.
RSpec.describe "OAuth write_articles scope" do
  let(:user) { create(:user) }

  let(:application) do
    Doorkeeper::Application.create!(
      name: "Federated site",
      redirect_uri: "https://example.test/auth/callback",
      scopes: "openid email profile write_articles",
      confidential: true,
    )
  end

  let(:article_params) do
    { article: { title: "Девлог: перша глава", body_markdown: "Текст девлогу", published: false,
                 canonical_url: "https://example.test/devlog/1" } }
  end

  def token_response_for(scope)
    sign_in user
    post "/oauth/authorize", params: {
      client_id: application.uid, redirect_uri: application.redirect_uri, response_type: "code", scope: scope
    }
    code = CGI.parse(URI.parse(response.redirect_url).query)["code"].first
    sign_out user

    post "/oauth/token", params: {
      grant_type: "authorization_code", code: code, client_id: application.uid,
      client_secret: application.plaintext_secret, redirect_uri: application.redirect_uri
    }
    response.parsed_body
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/vnd.forem.api-v1+json" }
  end

  it "creates and updates the member's article with a write_articles token" do
    token = token_response_for("openid write_articles")["access_token"]

    expect do
      post api_articles_path, params: article_params, headers: bearer(token), as: :json
    end.to change(user.articles, :count).by(1)
    expect(response).to have_http_status(:created)

    article = user.articles.last
    expect(article.canonical_url).to eq("https://example.test/devlog/1")

    put api_article_path(article.id), params: { article: { title: "Девлог: друга глава" } },
                                      headers: bearer(token), as: :json
    expect(response).to have_http_status(:ok)
    expect(article.reload.title).to eq("Девлог: друга глава")
  end

  it "does not let an admin's token edit other members' articles" do
    user.add_role(:super_admin)
    token = token_response_for("openid write_articles")["access_token"]
    other_article = create(:article, title: "Чужа стаття")

    put api_article_path(other_article.id), params: { article: { title: "Змінено" } }, headers: bearer(token), as: :json

    expect(response).to have_http_status(:not_found)
    expect(other_article.reload.title).to eq("Чужа стаття")
  end

  it "accepts the token on a private Forem" do
    allow(Settings::UserExperience).to receive(:public).and_return(false)
    token = token_response_for("openid write_articles")["access_token"]

    post api_articles_path, params: article_params, headers: bearer(token), as: :json

    expect(response).to have_http_status(:created)
  end

  it "rejects a sign-in token without the scope" do
    token = token_response_for("openid profile")["access_token"]

    expect do
      post api_articles_path, params: article_params, headers: bearer(token), as: :json
    end.not_to change(Article, :count)
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a revoked token" do
    token = token_response_for("openid write_articles")["access_token"]
    Doorkeeper::AccessToken.by_token(token).revoke
    post api_articles_path, params: article_params, headers: bearer(token), as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "does not let the token reach other API endpoints" do
    token = token_response_for("openid write_articles")["access_token"]

    get "/api/articles/me", headers: bearer(token)
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a token of a suspended member" do
    token = token_response_for("openid write_articles")["access_token"]
    user.add_role(:suspended)

    post api_articles_path, params: article_params, headers: bearer(token), as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "gives a refresh token only to write_articles, and it renews access" do
    expect(token_response_for("openid profile")["refresh_token"]).to be_nil

    refresh = token_response_for("openid write_articles")["refresh_token"]
    expect(refresh).to be_present

    post "/oauth/token", params: {
      grant_type: "refresh_token", refresh_token: refresh,
      client_id: application.uid, client_secret: application.plaintext_secret
    }
    expect(response).to have_http_status(:ok)
    renewed = response.parsed_body["access_token"]

    post api_articles_path, params: article_params, headers: bearer(renewed), as: :json
    expect(response).to have_http_status(:created)
  end

  it "refuses the scope to an application that was not granted it" do
    application.update!(scopes: "openid email profile")
    sign_in user

    post "/oauth/authorize", params: {
      client_id: application.uid, redirect_uri: application.redirect_uri, response_type: "code",
      scope: "openid write_articles"
    }
    expect(response.redirect_url).to include("error=invalid_scope")
  end

  it "shows what the site will be able to do on the consent screen" do
    sign_in user
    get "/oauth/authorize", params: {
      client_id: application.uid, redirect_uri: application.redirect_uri, response_type: "code",
      scope: "openid write_articles"
    }

    expect(response.body).to include(I18n.t("doorkeeper.scopes.write_articles"))
  end
end
