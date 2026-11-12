require "rails_helper"

RSpec.describe SocialAutopost::Ticker do
  include ActiveSupport::Testing::TimeHelpers

  let(:kyiv) { SocialAutopost::Schedule.time_zone }
  # Wednesday 19:05 Kyiv: inside the default weekday window.
  let(:now) { kyiv.local(2026, 11, 11, 19, 5) }
  let(:client) { instance_double(SocialAutopost::TelegramClient, send_message: "42") }

  def qualifying_article(score: 20, published_at: now - 2.days)
    article = create(:article)
    article.update_columns(score: score, published_at: published_at, body_markdown: "x" * 400)
    article
  end

  def tick(at = now)
    travel_to(at) { described_class.call(now: at, client: client) }
  end

  before do
    Settings::SocialAutopost.enabled = true
    Settings::SocialAutopost.telegram_bot_token = "123:abc"
    Settings::SocialAutopost.telegram_chat_id = "-100123"
    Settings::SocialAutopost.use_digest_filters = false
    Settings::SocialAutopost.minimum_body_length = 100
    Settings::SocialAutopost.official_organization_ids = ""
  end

  it "does nothing while disabled" do
    Settings::SocialAutopost.enabled = false
    qualifying_article

    expect(tick).to eq(:disabled)
    expect(SocialAutopostItem.count).to eq(0)
  end

  it "queues qualifying articles and posts the best one inside the window" do
    lower = qualifying_article(score: 20)
    higher = qualifying_article(score: 40)

    expect(tick).to eq(:posted)
    expect(client).to have_received(:send_message).once
    expect(SocialAutopostItem.find_by(article: higher)).to have_attributes(status: "posted", telegram_message_id: "42")
    expect(SocialAutopostItem.find_by(article: lower)).to be_queued
  end

  it "keeps the minimum interval between posts" do
    first = qualifying_article(score: 40)
    second = qualifying_article(score: 20)

    tick
    expect(tick(now + 60.minutes)).to eq(:waiting)
    expect(SocialAutopostItem.find_by(article: second)).to be_queued

    expect(tick(now + 121.minutes)).to eq(:posted)
    expect(SocialAutopostItem.where(article: [first, second]).pluck(:status)).to all(eq("posted"))
  end

  it "queues but does not post outside the windows" do
    qualifying_article

    expect(tick(kyiv.local(2026, 11, 11, 12, 0))).to eq(:closed)
    expect(SocialAutopostItem.queued.count).to eq(1)
    expect(client).not_to have_received(:send_message)
  end

  it "respects the daily limit" do
    Settings::SocialAutopost.max_posts_per_day = 1
    Settings::SocialAutopost.min_interval_minutes = 0
    2.times { qualifying_article }

    tick
    expect(tick(now + 10.minutes)).to eq(:daily_limit)
  end

  it "sends forced items outside the window and makes the schedule wait" do
    article = qualifying_article
    item = SocialAutopostItem.create!(article: article, source: "digest", kind: "digest", post_after: now)
    other = qualifying_article
    night = kyiv.local(2026, 11, 11, 23, 0)

    travel_to(night) { described_class.call(now: night, client: client) }

    expect(item.reload).to be_posted
    expect(SocialAutopostItem.find_by(article: other)).to be_queued
    expect(Time.zone.parse(Settings::SocialAutopost.next_post_not_before)).to eq(night + 120.minutes)
  end

  it "skips queued items that aged out and posts the next one" do
    stale = qualifying_article(score: 90)
    fresh = qualifying_article(score: 20)
    SocialAutopostItem.create!(article: stale)
    stale.update_columns(published_at: now - 31.days)

    tick
    expect(SocialAutopostItem.find_by(article: stale)).to have_attributes(status: "skipped", skip_reason: "too_old")
    expect(SocialAutopostItem.find_by(article: fresh)).to be_posted
  end

  it "skips articles unpublished while queued" do
    article = qualifying_article
    SocialAutopostItem.create!(article: article)
    article.update_columns(published: false)

    tick
    expect(SocialAutopostItem.find_by(article: article)).to have_attributes(status: "skipped",
                                                                            skip_reason: "unpublished")
    expect(client).not_to have_received(:send_message)
  end

  it "keeps the item queued when the bot setup is broken" do
    qualifying_article
    allow(client).to receive(:send_message)
      .and_raise(SocialAutopost::TelegramClient::Error.new("Telegram sendMessage failed: Unauthorized", code: 401))

    expect(tick).to eq(:setup_error)
    expect(SocialAutopostItem.last).to have_attributes(status: "queued", attempts: 0)
    expect(Settings::SocialAutopost.last_error).to include("Unauthorized")
  end

  it "gives up on a message after repeated message errors" do
    qualifying_article
    allow(client).to receive(:send_message)
      .and_raise(SocialAutopost::TelegramClient::Error.new("Telegram sendMessage failed: Bad Request: text is too long",
                                                           code: 400))

    3.times { |i| tick(now + i.minutes) }
    expect(SocialAutopostItem.last).to have_attributes(status: "failed", attempts: 3)
  end

  it "marks sends interrupted long ago as failed instead of retrying them" do
    item = SocialAutopostItem.create!(article: qualifying_article, status: "sending")
    item.update_columns(updated_at: now - 1.hour)

    tick
    expect(item.reload).to be_failed
  end

  it "uses the staff template for admins" do
    article = qualifying_article
    article.user.add_role(:admin)

    tick
    expect(SocialAutopostItem.find_by(article: article).kind).to eq("staff")
  end
end
