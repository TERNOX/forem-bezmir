require "rails_helper"

RSpec.describe "Projects", type: :request do
  describe "GET /projects" do
    it "renders organizations sorted by reputation by default" do
      low = create(:organization, reputation_score: 10, name: "Alpha Org")
      high = create(:organization, reputation_score: 25, name: "Beta Org")

      get projects_path

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body.index(high.name)).to be < body.index(low.name)
    end

    it "filters organizations by search query" do
      matching = create(:organization, name: "Team Phoenix")
      create(:organization, name: "Another Group")

      get projects_path, params: { q: "pho" }

      expect(response.body).to include(matching.name)
      expect(response.body).not_to include("Another Group")
    end

    it "supports sorting by creation date" do
      older = create(:organization, created_at: 2.weeks.ago, name: "Oldies")
      newer = create(:organization, created_at: 1.day.ago, name: "Fresh Ones")

      get projects_path, params: { sort: "created_at_asc" }

      body = response.body
      expect(body.index(older.name)).to be < body.index(newer.name)
    end
  end
end
