require "rails_helper"

RSpec.describe Articles::TopArticles::PeriodQuery, type: :service do
  describe ".call" do
    let(:start_time) { Time.zone.local(2024, 6, 1) }
    let(:end_time) { start_time + 1.week }

    before do
      allow(Settings::General).to receive(:top_articles_digest_excluded_organization_ids).and_return([])
    end

    it "returns article ids ordered by reaction count" do
      articles = create_list(:article, 3)

      create_list(:reaction, 5, reactable: articles[0], category: "like", created_at: start_time + 2.days)
      create_list(:reaction, 2, reactable: articles[1], category: "like", created_at: start_time + 1.day)
      create_list(:reaction, 4, reactable: articles[2], category: "like", created_at: start_time + 3.days)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 3)

      expect(result).to eq([articles[0].id, articles[2].id, articles[1].id])
    end

    it "ignores reactions outside the time range" do
      article = create(:article)
      create(:reaction, reactable: article, category: "like", created_at: start_time - 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to be_empty
    end

    it "excludes reactions on blocked organizations" do
      organization = create(:organization)
      allow(Settings::General).to receive(:top_articles_digest_excluded_organization_ids).and_return([organization.id])
      article = create(:article, organization: organization)
      create(:reaction, reactable: article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to be_empty
    end

    it "includes reactions for articles without an organization" do
      article = create(:article, organization: nil)
      create(:reaction, reactable: article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([article.id])
    end

    it "includes personal articles when exclusions are configured" do
      excluded_org = create(:organization)
      allow(Settings::General).to receive(:top_articles_digest_excluded_organization_ids).and_return([excluded_org.id])

      personal_article = create(:article, organization: nil)
      excluded_article = create(:article, organization: excluded_org)

      create(:reaction, reactable: personal_article, category: "like", created_at: start_time + 1.day)
      create(:reaction, reactable: excluded_article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([personal_article.id])
    end

    it "respects the provided limit" do
      articles = create_list(:article, 4)

      articles.each_with_index do |article, index|
        create_list(:reaction, index + 1, reactable: article, category: "like", created_at: start_time + 1.day)
      end

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 2)

      expect(result.length).to eq(2)
      expect(result).to eq([articles[3].id, articles[2].id])
    end
  end
end
