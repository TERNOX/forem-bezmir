require "rails_helper"

RSpec.describe SocialEmbeds::BlueskyClient do
  let(:at_uri) { "at://did:plc:abc/app.bsky.feed.post/xyz" }
  let(:endpoint) { "https://public.api.bsky.app/xrpc/app.bsky.feed.getPostThread" }

  def stub_thread(body, status: 200)
    stub_request(:get, endpoint)
      .with(query: hash_including({ "uri" => at_uri }))
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "returns normalized data with author, text and photos" do
    stub_thread({
                  "thread" => {
                    "$type" => "app.bsky.feed.defs#threadViewPost",
                    "post" => {
                      "author" => { "handle" => "alice.bsky.social", "displayName" => "Alice",
                                    "avatar" => "https://cdn/av.jpg" },
                      "record" => { "text" => "Hello", "createdAt" => "2026-01-02T03:04:05Z" },
                      "embed" => {
                        "$type" => "app.bsky.embed.images#view",
                        "images" => [{ "fullsize" => "https://cdn/full.jpg", "thumb" => "https://cdn/t.jpg",
                                       "alt" => "a cat" }]
                      }
                    }
                  }
                })

    data = described_class.fetch(at_uri: at_uri)

    expect(data).to be_ok
    expect(data.author_handle).to eq("alice.bsky.social")
    expect(data.author_name).to eq("Alice")
    expect(data.text_content).to eq("Hello")
    expect(data.photos).to eq([{ "url" => "https://cdn/full.jpg", "alt" => "a cat" }])
  end

  it "detects a deleted post via notFoundPost" do
    stub_thread({ "thread" => { "$type" => "app.bsky.feed.defs#notFoundPost", "notFound" => true } })

    expect(described_class.fetch(at_uri: at_uri).status).to eq(:deleted)
  end

  it "detects a deleted post via a NotFound error response" do
    stub_thread({ "error" => "NotFound", "message" => "Post not found" }, status: 400)

    expect(described_class.fetch(at_uri: at_uri).status).to eq(:deleted)
  end

  it "returns :unavailable on server error" do
    stub_thread({ "error" => "InternalServerError" }, status: 500)

    expect(described_class.fetch(at_uri: at_uri).status).to eq(:unavailable)
  end
end
