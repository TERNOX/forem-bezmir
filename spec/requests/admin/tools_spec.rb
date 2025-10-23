require "rails_helper"

RSpec.describe "/admin/advanced/tools" do
  context "when the user is not an admin" do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it "blocks the request" do
      expect do
        get admin_tools_path
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  context "when the user is a super admin" do
    let(:super_admin) { create(:user, :super_admin) }

    before do
      sign_in super_admin
      get admin_tools_path
    end

    it "allows the request" do
      expect(response).to have_http_status(:ok)
    end

    it "updates the top articles digest settings" do
      post update_top_articles_digest_admin_tools_path, params: {
        top_articles_digest: {
          bot_api_key: "abc123",
          title_template: "Digest {{current_date}}",
          tags: "digest, weekly",
          image_url: "https://example.com/image.png",
          organization_id: "",
          intro_paragraph: "Intro",
          frequency: "weekly",
          article_count: "5",
          badge_slug: "top-7",
        },
      }

      expect(response).to redirect_to(admin_tools_path(anchor: "top-articles-digest"))
      expect(Settings::General.top_articles_digest_bot_api_key).to eq("abc123")
      expect(Settings::General.top_articles_digest_tags).to eq(%w[digest weekly])
      expect(Settings::General.top_articles_digest_article_count).to eq(5)
    end
  end

  context "when the user is a single resource admin" do
    let(:single_resource_admin) { create(:user, :single_resource_admin, resource: Tool) }

    before do
      sign_in single_resource_admin
      get admin_tools_path
    end

    it "allows the request" do
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the user is the wrong single resource admin" do
    let(:single_resource_admin) { create(:user, :single_resource_admin, resource: Article) }

    before do
      sign_in single_resource_admin
    end

    it "blocks the request" do
      expect do
        get admin_tools_path
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
