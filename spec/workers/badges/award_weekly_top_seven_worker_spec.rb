require "rails_helper"

RSpec.describe Badges::AwardWeeklyTopSevenWorker do
  subject(:worker) { described_class.new }

  let(:schedule_zone) { Articles::TopArticles::DigestSchedule.time_zone }
  let(:current_time) do
    schedule_zone.local(2024, 6, 17, 20, 30, 0).in_time_zone(Time.zone)
  end
  let(:previous_week_start) { (current_time - 1.week).beginning_of_week(:monday) }
  let(:reaction_time) { previous_week_start + 2.days + 8.hours }

  before do
    create(:badge, slug: "top-7", title: "Top 7")
  end

  it "creates a selection and awards badges to the top authors" do
    travel_to(current_time) do
      articles = create_list(:article, 3)

      create_list(:reaction, 3, reactable: articles[0], category: "like", created_at: reaction_time)
      create_list(:reaction, 2, reactable: articles[1], category: "like", created_at: reaction_time)
      create(:reaction, reactable: articles[2], category: "like", created_at: reaction_time)

      allow(Badges::AwardTopSeven).to receive(:call)

      expect do
        worker.perform
      end.to change(TopSevenArticleSelection, :count).by(1)

      selection = TopSevenArticleSelection.last
      expect(selection.week_of).to eq(previous_week_start.to_date)
      expect(selection.article_ids).to eq([articles[0].id, articles[1].id, articles[2].id])
      expect(selection.awarded_at).to be_present

      expect(Badges::AwardTopSeven).to have_received(:call).with([
        articles[0].user.username,
        articles[1].user.username,
        articles[2].user.username,
      ])
    end
  end

  it "respects the configured article limit" do
    travel_to(current_time) do
      Settings::General.set_top_articles_digest_article_limit(2)
      articles = create_list(:article, 3)

      create_list(:reaction, 5, reactable: articles[0], category: "like", created_at: reaction_time)
      create_list(:reaction, 3, reactable: articles[1], category: "like", created_at: reaction_time)
      create_list(:reaction, 2, reactable: articles[2], category: "like", created_at: reaction_time)

      allow(Badges::AwardTopSeven).to receive(:call)

      worker.perform

      selection = TopSevenArticleSelection.last
      expect(selection.article_ids).to eq([articles[0].id, articles[1].id])
    end
  end

  it "does not award badges twice for the same week" do
    travel_to(current_time) do
      article = create(:article)
      create(:reaction, reactable: article, category: "like", created_at: reaction_time)

      worker.perform
      allow(Badges::AwardTopSeven).to receive(:call)

      expect do
        worker.perform
      end.not_to change(TopSevenArticleSelection, :count)

      expect(Badges::AwardTopSeven).not_to have_received(:call)
    end
  end

  it "skips awarding when there are no qualifying articles" do
    travel_to(current_time) do
      allow(Badges::AwardTopSeven).to receive(:call)

      expect do
        worker.perform
      end.not_to change(TopSevenArticleSelection, :count)

      expect(Badges::AwardTopSeven).not_to have_received(:call)
    end
  end

  it "skips awarding before the scheduled time" do
    early_time = schedule_zone.local(2024, 6, 17, 19, 0, 0).in_time_zone(Time.zone)

    travel_to(early_time) do
      article = create(:article)
      create(:reaction, reactable: article, category: "like", created_at: reaction_time)

      allow(Badges::AwardTopSeven).to receive(:call)

      expect do
        worker.perform
      end.not_to change(TopSevenArticleSelection, :count)

      expect(Badges::AwardTopSeven).not_to have_received(:call)
    end
  end

  it "awards within the Tuesday grace period" do
    tuesday_morning = schedule_zone.local(2024, 6, 18, 10, 0, 0).in_time_zone(Time.zone)

    travel_to(tuesday_morning) do
      articles = create_list(:article, 2)

      create_list(:reaction, 4, reactable: articles.first, category: "like", created_at: reaction_time)
      create_list(:reaction, 3, reactable: articles.second, category: "like", created_at: reaction_time)

      allow(Badges::AwardTopSeven).to receive(:call)

      worker.perform

      expect(Badges::AwardTopSeven).to have_received(:call)
    end
  end

  it "skips awarding once the window has passed" do
    late_tuesday = schedule_zone.local(2024, 6, 18, 21, 0, 0).in_time_zone(Time.zone)

    travel_to(late_tuesday) do
      allow(Badges::AwardTopSeven).to receive(:call)

      expect do
        worker.perform
      end.not_to change(TopSevenArticleSelection, :count)

      expect(Badges::AwardTopSeven).not_to have_received(:call)
    end
  end

  context "when the application time zone differs from UTC" do
    around do |example|
      Time.use_zone("Eastern Time (US & Canada)") { example.run }
    end

    let(:schedule_zone) { Articles::TopArticles::DigestSchedule.time_zone }
    let(:current_time) do
      schedule_zone.local(2024, 6, 17, 20, 15, 0).in_time_zone(Time.zone)
    end
    let(:article) { create(:article) }
    let(:selection) do
      instance_double(TopSevenArticleSelection, article_ids: [article.id], awarded_at: nil, update!: true)
    end

    before do
      allow(TopSevenArticleSelection).to receive(:ensure_for_week!).and_return(selection)
      allow(Badges::AwardTopSeven).to receive(:call)
    end

    it "awards badges once the Kyiv run window opens" do
      travel_to(current_time) { worker.perform }

      expect(TopSevenArticleSelection).to have_received(:ensure_for_week!).with(
        (current_time - 1.week).beginning_of_week(:monday).to_date
      )
      expect(Badges::AwardTopSeven).to have_received(:call).with([article.user.username])
    end
  end
end
