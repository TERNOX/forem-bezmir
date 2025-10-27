require "rails_helper"

RSpec.describe "Stories short links" do
  describe "GET /s/:id" do
    let!(:article) { create(:article) }

    it "redirects to the canonical article path" do
      get short_article_path(article.id)

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(article.path)
    end

    it "redirects using the slug when the cached path is missing" do
      article.update!(path: nil)

      get short_article_path(article.id)

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/#{article.username}/#{article.slug}")
    end

    it "returns not found for an unpublished article" do
      unpublished_article = create(:unpublished_article)

      get short_article_path(unpublished_article.id)

      expect(response).to have_http_status(:not_found)
    end

    it "returns not found for an unknown article" do
      get short_article_path(article.id + 1)

      expect(response).to have_http_status(:not_found)
    end
  end
end
