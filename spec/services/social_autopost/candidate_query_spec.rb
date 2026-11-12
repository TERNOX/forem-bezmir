require "rails_helper"

RSpec.describe SocialAutopost::CandidateQuery do
  let(:community_org) { create(:organization) }
  let(:official_org) { create(:organization) }

  def article_with(score: 20, published_at: 1.day.ago, body: "x" * 400, **attrs)
    article = create(:article, **attrs)
    article.update_columns(score: score, published_at: published_at, body_markdown: body)
    article
  end

  before do
    Settings::SocialAutopost.minimum_score = 15
    Settings::SocialAutopost.max_age_days = 30
    Settings::SocialAutopost.use_digest_filters = false
    Settings::SocialAutopost.minimum_body_length = 300
    Settings::SocialAutopost.minimum_video_body_length = 500
    Settings::SocialAutopost.official_organization_ids = official_org.id.to_s
  end

  it "picks well-rated recent community posts only" do
    good = article_with
    org_post = article_with(organization: community_org)
    low = article_with(score: 14)
    old = article_with(published_at: 31.days.ago)
    short = article_with(body: "x" * 100)
    official = article_with(organization: official_org)

    result = described_class.call
    expect(result).to include(good, org_post)
    expect(result).not_to include(low, old, short, official)
  end

  it "lets community favorites in regardless of rating" do
    favorite = article_with(score: 0)
    favorite.update_columns(favorited_by_user_id: create(:user).id)

    expect(described_class.call).to include(favorite)
    Settings::SocialAutopost.include_community_favorites = false
    expect(described_class.call).not_to include(favorite)
  end

  it "needs more text next to a video" do
    video = article_with(body: "x" * 400)
    video.update_columns(video: "https://example.com/video.m3u8")

    expect(described_class.call).not_to include(video)
    video.update_columns(body_markdown: "x" * 600)
    expect(described_class.call).to include(video)
  end

  it "skips articles that are already queued or posted" do
    article = article_with
    SocialAutopostItem.create!(article: article, status: "posted")
    expect(described_class.call).not_to include(article)
  end

  it "skips posts by banned authors" do
    article = article_with(user: create(:user, :suspended))
    expect(described_class.call).not_to include(article)
  end

  it "can leave staff posts out" do
    article = article_with(user: create(:user, :admin))
    expect(described_class.call).to include(article)

    Settings::SocialAutopost.include_staff_posts = false
    expect(described_class.call).not_to include(article)
  end

  it "includes official organizations when asked" do
    official = article_with(organization: official_org)
    Settings::SocialAutopost.include_official_posts = true
    expect(described_class.call).to include(official)
  end

  it "respects the published-after date" do
    article = article_with(published_at: 5.days.ago)
    Settings::SocialAutopost.published_after = 2.days.ago.to_date.iso8601
    expect(described_class.call).not_to include(article)
  end

  it "applies the minimum reactions" do
    article = article_with
    article.update_columns(public_reactions_count: 2)
    Settings::SocialAutopost.minimum_reactions = 3
    expect(described_class.call).not_to include(article)
  end

  context "with the digest filters" do
    before do
      Settings::SocialAutopost.use_digest_filters = true
      Settings::General.top_articles_digest_minimum_body_length = 1000
    end

    it "uses the digest minimum length" do
      article = article_with(body: "x" * 800)
      expect(described_class.call).not_to include(article)
      article.update_columns(body_markdown: "x" * 1200)
      expect(described_class.call).to include(article)
    end

    it "uses the digest excluded tags" do
      article = article_with(body: "x" * 1200, tags: "memes")
      Settings::General.top_articles_digest_excluded_tags = "memes"
      expect(described_class.call).not_to include(article)
    end
  end
end
