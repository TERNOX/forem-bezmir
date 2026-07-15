require "rails_helper"

RSpec.describe SocialEmbeds::TwitterClient do
  let(:id) { "1671839966572290048" }
  let(:url) { "https://twitter.com/i/status/#{id}" }
  let(:syndication) { "https://cdn.syndication.twimg.com/tweet-result" }
  let(:oembed) { "https://publish.twitter.com/oembed" }

  def stub_syndication(body: nil, status: 200)
    stub_request(:get, syndication)
      .with(query: hash_including({ "id" => id }))
      .to_return(status: status, body: body&.to_json.to_s, headers: { "Content-Type" => "application/json" })
  end

  def stub_oembed(body: nil, status: 200)
    stub_request(:get, oembed)
      .with(query: hash_including({ "url" => url }))
      .to_return(status: status, body: body&.to_json.to_s, headers: { "Content-Type" => "application/json" })
  end

  it "returns text, author and photos from syndication" do
    stub_syndication(body: {
                       "text" => "gm",
                       "user" => { "name" => "Alice", "screen_name" => "alice",
                                   "profile_image_url_https" => "https://pbs/av.jpg" },
                       "created_at" => "2026-01-02T03:04:05.000Z",
                       "photos" => [{ "url" => "https://pbs/a.jpg" }],
                     })

    data = described_class.fetch(source_id: id, source_url: url)

    expect(data).to be_ok
    expect(data.author_handle).to eq("alice")
    expect(data.text_content).to eq("gm")
    expect(data.photos).to eq([{ "url" => "https://pbs/a.jpg", "alt" => "" }])
  end

  it "detects deletion via syndication 404" do
    stub_syndication(status: 404)

    expect(described_class.fetch(source_id: id, source_url: url).status).to eq(:deleted)
  end

  it "detects deletion via syndication tombstone" do
    stub_syndication(body: { "__typename" => "TweetTombstone" })

    expect(described_class.fetch(source_id: id, source_url: url).status).to eq(:deleted)
  end

  it "does NOT mark a tweet deleted when syndication fails and oEmbed 404s" do
    stub_syndication(status: 500)
    stub_oembed(status: 404)

    # A live tweet whose oEmbed URL form is unsupported must not be archived.
    expect(described_class.fetch(source_id: id, source_url: url).status).to eq(:unavailable)
  end

  it "falls back to oEmbed text when syndication fails" do
    stub_syndication(status: 500)
    stub_oembed(body: {
                  "author_name" => "Alice",
                  "author_url" => "https://twitter.com/alice",
                  "html" => "<blockquote><p>hello from oembed</p></blockquote>",
                })

    data = described_class.fetch(source_id: id, source_url: url)

    expect(data).to be_ok
    expect(data.text_content).to eq("hello from oembed")
    expect(data.author_handle).to eq("alice")
  end
end
