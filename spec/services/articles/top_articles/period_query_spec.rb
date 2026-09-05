require "rails_helper"

RSpec.describe Articles::TopArticles::PeriodQuery, type: :service do
  describe ".call" do
    let(:start_time) { Time.zone.local(2024, 6, 1) }
    let(:end_time) { start_time + 1.week }
    let(:in_period_published_at) { start_time + 1.day }

    before do
      allow(Settings::General).to receive(:top_articles_digest_excluded_organization_ids).and_return([])
      allow(Settings::General).to receive(:top_articles_digest_minimum_score).and_return(0)
      allow(Settings::General).to receive(:top_articles_digest_excluded_tags).and_return([])
    end

    it "prioritizes articles with higher score before reaction count" do
      articles = create_list(:article, 3, published_at: in_period_published_at)

      create_list(:reaction, 5, reactable: articles[0], category: "like", created_at: start_time + 2.days)
      create_list(:reaction, 5, reactable: articles[1], category: "like", created_at: start_time + 1.day)
      create_list(:reaction, 5, reactable: articles[2], category: "like", created_at: start_time + 3.days)

      articles[1].update!(score: 30)
      articles[0].update!(score: 20)
      articles[2].update!(score: 10)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 3)

      expect(result).to eq([articles[1].id, articles[0].id, articles[2].id])
    end

    it "falls back to reaction count ordering when scores match" do
      articles = create_list(:article, 3, published_at: in_period_published_at)

      create_list(:reaction, 5, reactable: articles[0], category: "like", created_at: start_time + 2.days)
      create_list(:reaction, 2, reactable: articles[1], category: "like", created_at: start_time + 1.day)
      create_list(:reaction, 4, reactable: articles[2], category: "like", created_at: start_time + 3.days)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 3)

      expect(result).to eq([articles[0].id, articles[2].id, articles[1].id])
    end

    it "ignores reactions outside the time range" do
      article = create(:article, published_at: in_period_published_at)
      create(:reaction, reactable: article, category: "like", created_at: start_time - 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to be_empty
    end

    it "excludes reactions on blocked organizations" do
      organization = create(:organization)
      allow(Settings::General).to receive(:top_articles_digest_excluded_organization_ids).and_return([organization.id])
      article = create(:article, organization: organization, published_at: in_period_published_at)
      create(:reaction, reactable: article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to be_empty
    end

    it "includes reactions for articles without an organization" do
      article = create(:article, organization: nil, published_at: in_period_published_at)
      create(:reaction, reactable: article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([article.id])
    end

    it "includes personal articles when exclusions are configured" do
      excluded_org = create(:organization)
      allow(Settings::General).to receive(:top_articles_digest_excluded_organization_ids).and_return([excluded_org.id])

      personal_article = create(:article, organization: nil, published_at: in_period_published_at)
      excluded_article = create(:article, organization: excluded_org, published_at: in_period_published_at)

      create(:reaction, reactable: personal_article, category: "like", created_at: start_time + 1.day)
      create(:reaction, reactable: excluded_article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([personal_article.id])
    end

    it "respects the provided limit" do
      articles = create_list(:article, 4, published_at: in_period_published_at)

      articles.each_with_index do |article, index|
        create_list(:reaction, index + 1, reactable: article, category: "like", created_at: start_time + 1.day)
      end

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 2)

      expect(result.length).to eq(2)
      expect(result).to eq([articles[3].id, articles[2].id])
    end

    it "excludes articles with a negative score" do
      positive_article = create(:article, score: 5, published_at: in_period_published_at)
      negative_article = create(:article, score: -1, published_at: in_period_published_at)

      create(:reaction, reactable: positive_article, category: "like", created_at: start_time + 1.day)
      create(:reaction, reactable: negative_article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([positive_article.id])
    end

    it "excludes articles published outside the period even if they receive reactions within it" do
      old_article = create(:article, published_at: start_time - 2.months, score: 10)
      in_period_article = create(:article, published_at: in_period_published_at, score: 5)

      create(:reaction, reactable: old_article, category: "like", created_at: start_time + 2.days)
      create(:reaction, reactable: in_period_article, category: "like", created_at: start_time + 3.days)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([in_period_article.id])
    end

    it "excludes articles below the configured minimum score" do
      allow(Settings::General).to receive(:top_articles_digest_minimum_score).and_return(25)

      high_score_article = create(:article, score: 30, published_at: in_period_published_at)
      low_score_article = create(:article, score: 20, published_at: in_period_published_at)

      create(:reaction, reactable: high_score_article, category: "like", created_at: start_time + 1.day)
      create(:reaction, reactable: low_score_article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([high_score_article.id])
    end

    it "excludes articles tagged with configured tags" do
      allow(Settings::General).to receive(:top_articles_digest_excluded_tags).and_return(["news"])

      excluded_tag = create(:tag, name: "news")
      kept_article = create(:article, tag_list: "updates", published_at: in_period_published_at)
      skipped_article = create(:article, tag_list: excluded_tag.name, published_at: in_period_published_at)

      create(:reaction, reactable: kept_article, category: "like", created_at: start_time + 1.day)
      create(:reaction, reactable: skipped_article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([kept_article.id])
    end

    it "parses excluded tags stored as serialized strings" do
      allow(Settings::General)
        .to receive(:top_articles_digest_excluded_tags)
        .and_return('["українські-новини"]')

      excluded_tag = create(:tag, name: "українські-новини")
      kept_article = create(:article, tag_list: "інтерв'ю", published_at: in_period_published_at)
      skipped_article = create(:article, tag_list: excluded_tag.name, published_at: in_period_published_at)

      create(:reaction, reactable: kept_article, category: "like", created_at: start_time + 1.day)
      create(:reaction, reactable: skipped_article, category: "like", created_at: start_time + 1.day)

      result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

      expect(result).to eq([kept_article.id])
    end

    context "with Community Favorites (gems)" do
      let(:curator) { create(:user) }

      it "guarantees a gem published in the period a spot even without reactions" do
        gem_article = create(:article, published_at: in_period_published_at)
        gem_article.update_columns(favorited_by_user_id: curator.id, favorited_at: start_time + 1.day)

        popular = create(:article, published_at: in_period_published_at)
        create_list(:reaction, 5, reactable: popular, category: "like", created_at: start_time + 1.day)
        popular.update!(score: 50)

        result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

        expect(result).to include(gem_article.id)
        expect(result).to include(popular.id)
      end

      it "places gems ahead of reaction-ranked articles when slots are limited" do
        gem_article = create(:article, published_at: in_period_published_at)
        gem_article.update_columns(favorited_by_user_id: curator.id, favorited_at: start_time + 1.day)

        popular = create(:article, published_at: in_period_published_at)
        create_list(:reaction, 5, reactable: popular, category: "like", created_at: start_time + 1.day)
        popular.update!(score: 50)

        result = described_class.call(start_time: start_time, end_time: end_time, limit: 1)

        expect(result).to eq([gem_article.id])
      end

      it "does not duplicate a gem that also ranks by reactions" do
        gem_article = create(:article, published_at: in_period_published_at)
        create_list(:reaction, 5, reactable: gem_article, category: "like", created_at: start_time + 1.day)
        gem_article.update!(score: 40)
        gem_article.update_columns(favorited_by_user_id: curator.id, favorited_at: start_time + 1.day)

        result = described_class.call(start_time: start_time, end_time: end_time, limit: 5)

        expect(result.count(gem_article.id)).to eq(1)
      end
    end
  end
end
