require "rails_helper"

RSpec.describe Novelnya::Profiles do
  let(:feed_url) { "https://novelnya.com/embed/kutok/profiles" }
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:profile) do
    {
      "kutok_user_id" => 77,
      "name" => "Авторка",
      "username" => "avtorka",
      "url" => "https://novelnya.com/users/avtorka",
      "avatar_url" => "https://cdn.novelnya.com/a.png",
      "projects" => [
        { "title" => "Місто снів", "url" => "https://novelnya.com/projects/misto-sniv",
          "cover_url" => "https://cdn.novelnya.com/c.png" },
        { "title" => "Чужа", "url" => "https://evil.example/projects/x", "cover_url" => nil },
      ]
    }
  end

  around do |example|
    original_cache = Rails.cache
    Rails.cache = cache_store
    example.run
  ensure
    Rails.cache = original_cache
  end

  def stub_feed(profiles)
    stub_request(:get, feed_url).to_return(
      status: 200, body: { profiles: profiles }.to_json, headers: { "Content-Type" => "application/json" },
    )
  end

  it "stores opted-in profiles by Kutok user id, keeping only links to Новельня" do
    stub_feed([profile, profile.merge("kutok_user_id" => 78, "url" => "https://evil.example/users/x")])

    expect(described_class.refresh!).to eq([77])
    expect(described_class.for(77)).to include(
      name: "Авторка", username: "avtorka", url: "https://novelnya.com/users/avtorka",
      avatar_url: "https://cdn.novelnya.com/a.png",
      projects: [{ title: "Місто снів", url: "https://novelnya.com/projects/misto-sniv",
                   cover_url: "https://cdn.novelnya.com/c.png" }]
    )
    expect(described_class.for(78)).to be_nil
  end

  it "reports who was removed or changed on the next refresh" do
    stub_feed([profile])
    described_class.refresh!

    stub_feed([])
    expect(described_class.refresh!).to eq([77])
    expect(described_class.for(77)).to be_nil
  end

  it "keeps the last good list when Новельня is unavailable" do
    stub_feed([profile])
    described_class.refresh!

    stub_request(:get, feed_url).to_return(status: 503, body: "closed")
    expect(described_class.refresh!).to eq([])

    stub_request(:get, feed_url).to_timeout
    expect(described_class.refresh!).to eq([])

    expect(described_class.for(77)).to include(username: "avtorka")
  end

  it "purges pages still showing a block once the list expired during an outage" do
    stub_feed([profile])
    described_class.refresh!
    Rails.cache.delete(described_class::CACHE_KEY) # the list expired

    stub_request(:get, feed_url).to_return(status: 503, body: "closed")
    expect(described_class.refresh!).to eq([77])
    expect(described_class.refresh!).to eq([])
  end

  it "purges a member who left while the list was expired" do
    stub_feed([profile])
    described_class.refresh!
    Rails.cache.delete(described_class::CACHE_KEY) # the list expired

    stub_feed([])
    expect(described_class.refresh!).to eq([77])
  end
end
