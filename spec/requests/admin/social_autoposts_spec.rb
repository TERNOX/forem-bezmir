require "rails_helper"

RSpec.describe "Admin::SocialAutoposts" do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :super_admin) }
  let(:article) { create(:article) }

  before { sign_in admin }

  it "denies regular members" do
    sign_in create(:user)
    expect { get admin_social_autoposts_path }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "shows the page with the queue and history" do
    SocialAutopostItem.create!(article: article)
    SocialAutopostItem.create!(article: create(:article), status: "posted", posted_at: Time.current,
                               sent_message: "Sent text")

    get admin_social_autoposts_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(CGI.escapeHTML(article.title), "Sent text", "Допис від нашого користувача")
  end

  it "estimates times that respect one post per author per day" do
    Settings::SocialAutopost.enabled = true
    Settings::SocialAutopost.telegram_bot_token = "123:abc"
    Settings::SocialAutopost.telegram_chat_id = "-100123"
    author = create(:user)
    first = SocialAutopostItem.create!(article: create(:article, user: author), priority: 3)
    second = SocialAutopostItem.create!(article: create(:article, user: author), priority: 2)
    other = SocialAutopostItem.create!(article: create(:article), priority: 1)

    # Wednesday 18:00 Kyiv, before the 19:00-21:30 window.
    travel_to(SocialAutopost::Schedule.time_zone.local(2026, 11, 11, 18, 0)) { get admin_social_autoposts_path }

    page = Nokogiri::HTML(response.body)
    estimate = ->(item) { page.at_css("#item-#{item.id} td").text.strip }
    expect(estimate.call(first)).to eq("Wed 11.11 19:00")
    expect(estimate.call(other)).to eq("Wed 11.11 21:00")
    expect(estimate.call(second)).to eq("Thu 12.11 19:00")
  end

  it "saves settings and keeps the token when the field is left empty" do
    Settings::SocialAutopost.telegram_bot_token = "123:abc"

    patch update_settings_admin_social_autoposts_path, params: {
      social_autopost: {
        enabled: "1", telegram_bot_token: "", telegram_chat_id: "-100555", minimum_score: "25",
        schedule_monday: "18:00-20:00, 21:00-22:00", official_organization_ids: ["", "7"],
        template_community: "{{title}}\n{{short_url}}"
      }
    }

    expect(response).to redirect_to(admin_social_autoposts_path)
    expect(Settings::SocialAutopost.enabled).to be(true)
    expect(Settings::SocialAutopost.telegram_bot_token).to eq("123:abc")
    expect(Settings::SocialAutopost.telegram_chat_id).to eq("-100555")
    expect(Settings::SocialAutopost.minimum_score).to eq(25)
    expect(Settings::SocialAutopost.schedule_monday).to eq("18:00-20:00, 21:00-22:00")
    expect(SocialAutopost.official_organization_ids).to eq([7])
  end

  it "rejects a malformed schedule without saving anything" do
    patch update_settings_admin_social_autoposts_path,
          params: { social_autopost: { minimum_score: "99", schedule_friday: "evening" } }

    expect(flash[:danger]).to include("Invalid posting window")
    expect(Settings::SocialAutopost.minimum_score).to eq(15)
  end

  it "rejects a value that is not a bot token or a channel id" do
    Settings::SocialAutopost.telegram_bot_token = "123:abc"

    patch update_settings_admin_social_autoposts_path,
          params: { social_autopost: { telegram_bot_token: "http://user@host/#1" } }
    expect(flash[:danger]).to include("not a bot token")
    expect(Settings::SocialAutopost.telegram_bot_token).to eq("123:abc")

    patch update_settings_admin_social_autoposts_path, params: { social_autopost: { telegram_chat_id: "Куток" } }
    expect(flash[:danger]).to include("Channel id")
  end

  it "marks a forced item that failed to send instead of showing it as sending" do
    SocialAutopostItem.create!(article: article, source: "manual", post_after: 1.minute.ago,
                               last_error: "Telegram sendMessage failed: Bad Request: chat not found")
    Settings::SocialAutopost.last_error = "Telegram sendMessage failed: Bad Request: chat not found"

    get admin_social_autoposts_path
    expect(response.body).to include("Not sent, retrying", "error: Telegram sendMessage failed", "Last error")
    expect(response.body).not_to include("Sending now")
  end

  it "reports a broken saved token instead of failing on Check bot" do
    Settings::SocialAutopost.telegram_bot_token = "http://user@host/#1"
    Settings::SocialAutopost.telegram_chat_id = "-100123"

    post check_bot_admin_social_autoposts_path
    expect(response).to redirect_to(admin_social_autoposts_path)
    expect(flash[:danger]).to include("not a @BotFather token")
  end

  it "adds an article by its short link" do
    post add_item_admin_social_autoposts_path, params: { article: "https://kutok.io/s/#{article.id}" }
    expect(SocialAutopostItem.find_by(article: article)).to have_attributes(source: "manual", status: "queued")
  end

  it "edits, skips and requeues an item" do
    item = SocialAutopostItem.create!(article: article)

    patch admin_social_autopost_item_path(item), params: { social_autopost_item: { custom_message: "Свій текст" } }
    expect(item.reload.message).to eq("Свій текст")

    patch skip_admin_social_autopost_item_path(item)
    expect(item.reload).to be_skipped

    patch requeue_admin_social_autopost_item_path(item)
    expect(item.reload).to be_queued
  end

  it "sends an item now" do
    Settings::SocialAutopost.telegram_bot_token = "123:abc"
    Settings::SocialAutopost.telegram_chat_id = "-100123"
    allow(SocialAutopost::PostItemWorker).to receive(:perform_async)
    item = SocialAutopostItem.create!(article: article)

    post post_now_admin_social_autopost_item_path(item)

    expect(item.reload.post_after).to be_present
    expect(SocialAutopost::PostItemWorker).to have_received(:perform_async).with(item.id)
  end
end
