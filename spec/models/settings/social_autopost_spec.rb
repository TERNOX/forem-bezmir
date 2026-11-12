require "rails_helper"

RSpec.describe Settings::SocialAutopost do
  after do
    RequestStore.store.delete(:subforem_id)
    RequestStore.store.delete(:default_subforem_id)
  end

  it "writes global rows even inside a subforem request, so workers see them" do
    subforem = create(:subforem)
    RequestStore.store[:subforem_id] = subforem.id
    RequestStore.store[:default_subforem_id] = subforem.id

    described_class.enabled = true
    described_class.set_telegram_chat_id("-100777")

    expect(described_class.where(var: %w[enabled telegram_chat_id]).pluck(:subforem_id)).to all(be_nil)
    expect(RequestStore.store[:subforem_id]).to eq(subforem.id)

    # A Sidekiq job has no subforem in RequestStore.
    RequestStore.store.delete(:subforem_id)
    RequestStore.store.delete(:default_subforem_id)
    described_class.clear_cache
    expect(described_class.enabled).to be(true)
    expect(described_class.telegram_chat_id).to eq("-100777")
  end

  it "reads the global value inside a subforem request" do
    described_class.minimum_score = 42
    RequestStore.store[:subforem_id] = create(:subforem).id
    described_class.clear_cache

    expect(described_class.minimum_score).to eq(42)
  end
end
