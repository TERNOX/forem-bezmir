require "rails_helper"

RSpec.describe TopArticles::PublishDigestWorker do
  subject(:worker) { described_class.new }

  let(:bot_user) { create(:user, type_of: :community_bot) }
  let(:api_secret) { create(:api_secret, user: bot_user) }
  let(:article_one) { create(:article) }
  let(:article_two) { create(:article) }
  let(:selection) do
    TopSevenArticleSelection.create!(
      week_of: Date.new(2024, 6, 10),
      frequency: "weekly",
      article_ids: [article_one.id, article_two.id],
    )
  end

  before do
    allow(Settings::General).to receive(:top_articles_digest_frequency).and_return("weekly")
    allow(Settings::General).to receive(:top_articles_digest_article_count).and_return(2)
    allow(Settings::General).to receive(:top_articles_digest_badge_slug).and_return("top-7")
    allow(Settings::General).to receive(:top_articles_digest_bot_api_key).and_return(api_secret.secret)
    allow(Settings::General).to receive(:top_articles_digest_title_template).and_return("Digest {{period_label}}")
    allow(Settings::General).to receive(:top_articles_digest_tags).and_return(%w[top])
    allow(Settings::General).to receive(:top_articles_digest_image_url).and_return("https://example.com/image.png")
    allow(Settings::General).to receive(:top_articles_digest_organization_id).and_return(nil)
    allow(Settings::General).to receive(:top_articles_digest_intro_paragraph).and_return("Intro paragraph")
  end

  it "creates a digest article and records the relationship" do
    expect do
      worker.perform(selection.id)
    end.to change(Article, :count).by(1)

    selection.reload

    digest_article = Article.find(selection.digest_article_id)
    expect(digest_article.user).to eq(bot_user)
    expect(digest_article.tag_list).to include("top")
    expect(digest_article.body_markdown).to include("{% embed #{URL.article(article_one)} %}")
    expect(digest_article.body_markdown).to include("Intro paragraph")
  end

  it "does nothing when the API key is missing" do
    allow(Settings::General).to receive(:top_articles_digest_bot_api_key).and_return(nil)

    expect do
      worker.perform(selection.id)
    end.not_to change(Article, :count)
  end
end
