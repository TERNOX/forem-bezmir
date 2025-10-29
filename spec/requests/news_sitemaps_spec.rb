require "rails_helper"

RSpec.describe "News sitemap" do
  describe "GET /sitemap-news.xml" do
    let(:organization) { create(:organization) }

    before do
      allow(Settings::General).to receive(:news_sitemap_tags).and_return(%w[новини])
      allow(Settings::General).to receive(:news_sitemap_organization_ids).and_return([organization.id.to_s])
    end

    it "renders matching articles" do
      article = create(:article,
                       organization: organization,
                       tag_list: "новини",
                       published: true,
                       published_at: Time.current)

      get "/sitemap-news.xml"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include(URL.article(article))
      expect(response.body).to include(article.title)
    end

    it "excludes articles that do not match the filters" do
      other_tag = create(:article,
                         organization: organization,
                         tag_list: "різне",
                         published: true,
                         published_at: Time.current)
      other_org = create(:article,
                         organization: create(:organization),
                         tag_list: "новини",
                         published: true,
                         published_at: Time.current)
      outdated = create(:article,
                         organization: organization,
                         tag_list: "новини",
                         published: true,
                         published_at: 3.days.ago)

      get "/sitemap-news.xml"

      expect(response.body).not_to include(URL.article(other_tag))
      expect(response.body).not_to include(URL.article(other_org))
      expect(response.body).not_to include(URL.article(outdated))
    end
  end
end
