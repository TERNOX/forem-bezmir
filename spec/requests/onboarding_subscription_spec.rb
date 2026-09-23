require "rails_helper"

RSpec.describe "Onboarding subscription promotion" do
  let(:user) { create(:user, saw_onboarding: true) }
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

  around do |example|
    original_perform_caching = ActionController::Base.perform_caching
    original_cache_store = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = cache_store

    example.run
  ensure
    ActionController::Base.perform_caching = original_perform_caching
    ActionController::Base.cache_store = original_cache_store
  end

  before do
    sign_in user
    allow(Rails).to receive(:cache).and_return(cache_store)
    allow(Settings::General).to receive_messages(
      subscription_product_name: "Community Plus",
      subscription_landing_page_url: "/community-plus",
    )
  end

  def subscription_link
    Nokogiri::HTML(response.body).at_css('.onboarding-task-card a[href="/community-plus"]')
  end

  it "removes the promotion when subscriptions are disabled after the feed has been cached" do
    FeatureFlag.enable(:subscriber_icon)
    get root_path
    expect(response).to have_http_status(:ok)
    expect(subscription_link).to be_present

    FeatureFlag.disable(:subscriber_icon)
    get root_path

    expect(response).to have_http_status(:ok)
    expect(subscription_link).to be_nil
    expect(response.body).to include("onboarding-task-card")
    expect(Nokogiri::HTML(response.body).at_css('.onboarding-task-card a[href="/settings"]')).to be_present
  end

  it "shows the promotion when subscriptions are enabled after the feed has been cached" do
    FeatureFlag.disable(:subscriber_icon)
    get root_path
    expect(subscription_link).to be_nil

    FeatureFlag.enable(:subscriber_icon)
    get root_path

    expect(response).to have_http_status(:ok)
    expect(subscription_link).to be_present
    expect(subscription_link.text).to include("Community Plus")
  end
end
