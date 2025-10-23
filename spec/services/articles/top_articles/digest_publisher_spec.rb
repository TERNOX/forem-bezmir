require "rails_helper"

RSpec.describe Articles::TopArticles::DigestPublisher, type: :service do
  let(:reference_time) { Time.zone.local(2024, 6, 17, 0, 0, 0) }
  let(:week_start) { (reference_time - 1.week).beginning_of_week(:monday) }
  let(:reaction_time) { week_start + 2.days + 10.hours }

  def create_top_article_with_reactions(reaction_count: 3)
    article = create(:article)
    create_list(:reaction, reaction_count, reactable: article, category: "like", created_at: reaction_time)
    article
  end

  describe "#preview" do
    it "returns the articles for the configured time period even without a bot" do
      travel_to(reference_time) do
        top_article = create_top_article_with_reactions(reaction_count: 5)
        runner_up = create_top_article_with_reactions(reaction_count: 3)

        preview = described_class.new(reference_time: reference_time).preview

        expect(preview[:available?]).to be(true)
        expect(preview[:articles].map(&:id)).to eq([top_article.id, runner_up.id])
        expect(preview[:embed_urls]).to all(match(%r{\A\{% embed https://}))
      end
    end
  end

  describe "#call" do
    let(:api_secret) { create(:api_secret) }

    before do
      Settings::General.set_top_articles_digest_bot_api_key(api_secret.secret)
      Settings::General.set_top_articles_digest_title_template("Top {{count}} posts for {{period_end}}")
      Settings::General.set_top_articles_digest_intro_markdown("Intro paragraph")
      Settings::General.set_top_articles_digest_tags("digest, weekly")
      Settings::General.set_top_articles_digest_article_limit(2)
      Settings::General.set_top_articles_digest_frequency("weekly")
    end

    it "publishes a digest article with embeds" do
      travel_to(reference_time) do
        create_top_article_with_reactions(reaction_count: 5)
        create_top_article_with_reactions(reaction_count: 4)
        create_top_article_with_reactions(reaction_count: 1)

        expect do
          described_class.new(reference_time: reference_time).call
        end.to change(Article, :count).by(1)

        digest_article = Article.order(:created_at).last
        expect(digest_article.user).to eq(api_secret.user)
        tags = digest_article.cached_tag_list.split(/,\s*/)
        expect(tags).to include("digest", "weekly")
        expect(digest_article.published).to be(true)
        expect(digest_article.body_markdown).to include("Intro paragraph")
        expect(digest_article.body_markdown.scan("{% embed").length).to eq(2)
        expect(Settings::General.top_articles_digest_last_period_identifier).to eq("weekly:#{week_start.to_date.iso8601}")
        expect(Settings::General.top_articles_digest_last_article_id).to eq(digest_article.id)
      end
    end

    it "does not publish twice for the same period" do
      travel_to(reference_time) do
        create_top_article_with_reactions(reaction_count: 5)

        described_class.new(reference_time: reference_time).call

        expect do
          described_class.new(reference_time: reference_time).call
        end.not_to change(Article, :count)
      end
    end
  end
end
