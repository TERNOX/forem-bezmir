require "rails_helper"

RSpec.describe "Projects", type: :request do
  describe "GET /projects" do
    let!(:newer_project) { create(:organization, name: "New Project", created_at: 1.day.ago, articles_count: 2) }
    let!(:older_project) { create(:organization, name: "Old Project", created_at: 2.weeks.ago, articles_count: 5) }

    it "returns a successful response" do
      get "/projects"

      expect(response).to have_http_status(:ok)
    end

    it "orders organizations by newest first by default" do
      get "/projects"

      expect(assigns(:projects).map(&:id)).to eq([newer_project.id, older_project.id])
    end

    it "orders organizations by article count when requested" do
      get "/projects", params: { sort: "articles_count-desc" }

      expect(assigns(:projects).first).to eq(older_project)
    end

    it "filters organizations by the search query" do
      get "/projects", params: { q: "New" }

      expect(assigns(:projects)).to contain_exactly(newer_project)
    end
  end
end
