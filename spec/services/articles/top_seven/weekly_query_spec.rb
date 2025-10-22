require "rails_helper"

RSpec.describe Articles::TopSeven::WeeklyQuery, type: :service do
  let(:week_start) { Date.new(2024, 6, 3) }
  let(:range_start) { Time.zone.local(2024, 6, 3, 0, 0, 0) }
  let(:range_middle) { range_start + 2.days + 12.hours }

  it "returns up to seven article ids ordered by reaction count" do
    travel_to(range_start + 1.week + 1.day) do
      articles = create_list(:article, 8)

      articles.each_with_index do |article, index|
        (index + 1).times do
          create(:reaction, reactable: article, category: "like", created_at: range_middle)
        end
      end

      result = described_class.call(week_start)

      expect(result.length).to eq(7)
      expect(result).to eq(articles.first(7).reverse.map(&:id))
    end
  end

  it "ignores reactions outside the target week" do
    travel_to(range_start + 1.week + 1.day) do
      article = create(:article)
      create(:reaction, reactable: article, category: "like", created_at: range_start - 1.day)
      create(:reaction, reactable: article, category: "like", created_at: range_start + 1.day)

      result = described_class.call(week_start)

      expect(result).to eq([article.id])
    end
  end

  it "excludes articles that belong to filtered organizations" do
    travel_to(range_start + 1.week + 1.day) do
      excluded_org = create(:organization)
      stub_const("Articles::TopSeven::WeeklyQuery::EXCLUDED_ORGANIZATION_IDS", [excluded_org.id])
      excluded_article = create(:article, organization: excluded_org)
      included_article = create(:article)

      create(:reaction, reactable: excluded_article, category: "like", created_at: range_middle)
      create(:reaction, reactable: included_article, category: "like", created_at: range_middle)

      result = described_class.call(week_start)

      expect(result).to eq([included_article.id])
    end
  end

  it "ignores non-positive reactions" do
    travel_to(range_start + 1.week + 1.day) do
      article = create(:article)
      create(:thumbsdown_reaction, reactable: article, created_at: range_middle)

      result = described_class.call(week_start)

      expect(result).to be_empty
    end
  end
end
