require "rails_helper"

RSpec.describe "Projects", type: :request do
  describe "GET /projects" do
    it "returns success" do
      get projects_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("views.projects.index.heading"))
    end
  end

  describe "GET /projects.json" do
    let!(:high_reputation) do
      create(:organization, name: "Alpha Builders", reputation_score: 12, created_at: 3.days.ago)
    end
    let!(:low_reputation) do
      create(:organization, name: "Beta Labs", reputation_score: 2, created_at: 10.days.ago)
    end
    let!(:newest) do
      create(:organization, name: "Gamma Works", reputation_score: 5, created_at: 1.day.ago)
    end

    it "returns organizations ordered by reputation desc by default" do
      get projects_path(format: :json)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.fetch("projects").first.fetch("name")).to eq(high_reputation.name)
      expect(data.fetch("meta").fetch("total_count")).to eq(3)
    end

    it "filters by search term" do
      get projects_path(format: :json), params: { q: "Gamma" }

      names = JSON.parse(response.body).fetch("projects").map { |proj| proj.fetch("name") }
      expect(names).to eq([newest.name])
    end

    it "sorts by oldest" do
      get projects_path(format: :json), params: { sort: "oldest" }

      names = JSON.parse(response.body).fetch("projects").map { |proj| proj.fetch("name") }
      expect(names.first).to eq(low_reputation.name)
    end

    it "sorts by lowest reputation" do
      get projects_path(format: :json), params: { sort: "reputation_asc" }

      names = JSON.parse(response.body).fetch("projects").map { |proj| proj.fetch("name") }
      expect(names.first).to eq(low_reputation.name)
    end

    it "paginates results" do
      create_list(:organization, 3)

      get projects_path(format: :json), params: { per_page: 2 }

      data = JSON.parse(response.body)
      expect(data.fetch("projects").size).to eq(2)
      expect(data.fetch("meta").fetch("total_pages")).to be > 1
    end
  end
end
