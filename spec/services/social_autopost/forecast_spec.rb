require "rails_helper"

RSpec.describe SocialAutopost::Forecast do
  let(:kyiv) { SocialAutopost::Schedule.time_zone }
  # Monday 10:00 Kyiv, before the day's only window.
  let(:now) { kyiv.local(2026, 11, 9, 10, 0) }
  let(:busy_author) { create(:user) }

  def queued_article(score:, user: create(:user))
    article = create(:article, user: user)
    article.update_columns(score: score)
    SocialAutopostItem.create!(article: article)
  end

  def forecast
    items = SocialAutopostItem.ordered_queue.includes(:article).to_a
    times = described_class.call(items, limit: 10, now: now)
    times.transform_values { |time| time.in_time_zone(kyiv).strftime("%a %H:%M") }
  end

  before do
    Settings::SocialAutopost.enabled = true
    Settings::SocialAutopost.telegram_bot_token = "123:abc"
    Settings::SocialAutopost.telegram_chat_id = "-100123"
    Settings::SocialAutopost::WEEKDAYS.each do |day|
      Settings::SocialAutopost.public_send(:"schedule_#{day}=", "20:00-21:00")
    end
    Settings::SocialAutopost.min_interval_minutes = 144
  end

  it "takes turns between authors when there is one slot a day" do
    busy = Array.new(3) { |i| queued_article(score: 30 - i, user: busy_author) }
    newcomer = queued_article(score: 13)

    expect(forecast).to eq(busy[0].id => "Mon 20:00", newcomer.id => "Tue 20:00",
                           busy[1].id => "Wed 20:00", busy[2].id => "Thu 20:00")
  end

  it "starts with authors who were not posted recently" do
    old = create(:article, user: busy_author)
    SocialAutopostItem.create!(article: old, status: "posted", posted_at: now - 2.days)
    busy = queued_article(score: 30, user: busy_author)
    newcomer = queued_article(score: 13)

    expect(forecast).to eq(newcomer.id => "Mon 20:00", busy.id => "Tue 20:00")
  end

  it "keeps the plain queue order with rotation off" do
    Settings::SocialAutopost.rotate_authors = false
    busy = Array.new(3) { |i| queued_article(score: 30 - i, user: busy_author) }
    newcomer = queued_article(score: 13)

    expect(forecast).to eq(busy[0].id => "Mon 20:00", busy[1].id => "Tue 20:00",
                           busy[2].id => "Wed 20:00", newcomer.id => "Thu 20:00")
  end
end
