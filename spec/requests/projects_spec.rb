require "rails_helper"

RSpec.describe "Projects", type: :request do
  describe "GET /projects" do
    let!(:newer_org) { create(:organization, name: "New Org", created_at: 1.day.ago, articles_count: 2) }
    let!(:older_org) { create(:organization, name: "Old Org", created_at: 2.weeks.ago, articles_count: 5) }

    it "returns a successful response" do
      get "/projects"

      expect(response).to have_http_status(:ok)
    end

    it "orders organizations by newest first by default" do
      get "/projects"

      expect(assigns(:organizations).map(&:id)).to eq([newer_org.id, older_org.id])
    end

    it "orders organizations by article count when requested" do
      get "/projects", params: { sort: "articles_count-desc" }

      expect(assigns(:organizations).first).to eq(older_org)
    end

    it "filters organizations by the search query" do
      get "/projects", params: { q: "New" }

      expect(assigns(:organizations)).to contain_exactly(newer_org)
    end
  end
end
