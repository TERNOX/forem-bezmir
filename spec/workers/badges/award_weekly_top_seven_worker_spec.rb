require "rails_helper"

RSpec.describe Badges::AwardWeeklyTopSevenWorker do
  subject(:worker) { described_class.new }

  let(:current_time) { Time.zone.local(2024, 6, 17, 0, 0, 0) }
  let(:previous_week_start) { (current_time - 1.week).beginning_of_week(:monday) }
  let(:reaction_time) { previous_week_start + 2.days + 8.hours }

  before do
    create(:badge, slug: "top-7", title: "Top 7")
    allow(Settings::General).to receive(:top_articles_digest_frequency).and_return("weekly")
    allow(Settings::General).to receive(:top_articles_digest_article_count).and_return(3)
    allow(Settings::General).to receive(:top_articles_digest_badge_slug).and_return("top-7")
    allow(Settings::General).to receive(:top_articles_digest_bot_api_key).and_return(nil)
    allow(Settings::General).to receive(:top_articles_digest_title_template).and_return("Top {{count}} posts")
    allow(Settings::General).to receive(:top_articles_digest_tags).and_return(%w[top-7])
    allow(Settings::General).to receive(:top_articles_digest_image_url).and_return(nil)
    allow(Settings::General).to receive(:top_articles_digest_organization_id).and_return(nil)
    allow(Settings::General).to receive(:top_articles_digest_intro_paragraph).and_return("")
  end

  it "creates a selection and awards badges to the top authors" do
    travel_to(current_time) do
      articles = create_list(:article, 3)

      create_list(:reaction, 3, reactable: articles[0], category: "like", created_at: reaction_time)
      create_list(:reaction, 2, reactable: articles[1], category: "like", created_at: reaction_time)
      create(:reaction, reactable: articles[2], category: "like", created_at: reaction_time)

      allow(Badges::AwardTopSeven).to receive(:call)
      allow(TopArticles::PublishDigestWorker).to receive(:perform_async)

      expect do
        worker.perform
      end.to change(TopSevenArticleSelection, :count).by(1)

      selection = TopSevenArticleSelection.last
      expect(selection.week_of).to eq(previous_week_start.to_date)
      expect(selection.article_ids).to eq([articles[0].id, articles[1].id, articles[2].id])
      expect(selection.awarded_at).to be_present
      expect(selection.frequency).to eq("weekly")

      expect(Badges::AwardTopSeven).to have_received(:call).with([
        articles[0].user.username,
        articles[1].user.username,
        articles[2].user.username,
      ], badge_slug: "top-7")
      expect(TopArticles::PublishDigestWorker).to have_received(:perform_async).with(selection.id)
    end
  end

  it "does not award badges twice for the same week" do
    travel_to(current_time) do
      article = create(:article)
      create(:reaction, reactable: article, category: "like", created_at: reaction_time)

      allow(TopArticles::PublishDigestWorker).to receive(:perform_async)

      worker.perform
      allow(Badges::AwardTopSeven).to receive(:call)

      expect do
        worker.perform
      end.not_to change(TopSevenArticleSelection, :count)

      expect(Badges::AwardTopSeven).not_to have_received(:call)
      expect(TopArticles::PublishDigestWorker).to have_received(:perform_async).once
    end
  end

  it "skips awarding when there are no qualifying articles" do
    travel_to(current_time) do
      allow(Badges::AwardTopSeven).to receive(:call)
      allow(TopArticles::PublishDigestWorker).to receive(:perform_async)

      expect do
        worker.perform
      end.not_to change(TopSevenArticleSelection, :count)

      expect(Badges::AwardTopSeven).not_to have_received(:call)
      expect(TopArticles::PublishDigestWorker).not_to have_received(:perform_async)
    end
  end
end
