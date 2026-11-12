require "rails_helper"

RSpec.describe "Admin::SocialAutoposts" do
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
