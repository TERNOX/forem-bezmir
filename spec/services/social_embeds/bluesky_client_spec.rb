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

  it "resolves a handle-based at_uri to its DID before fetching" do
    stub_request(:get, "https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle")
      .with(query: { handle: "alice.bsky.social" })
      .to_return(status: 200, body: { did: "did:plc:alice" }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:get, endpoint)
      .with(query: hash_including({ "uri" => "at://did:plc:alice/app.bsky.feed.post/xyz" }))
      .to_return(
        status: 200,
        body: {
          "thread" => {
            "$type" => "app.bsky.feed.defs#threadViewPost",
            "post" => { "author" => { "handle" => "alice.bsky.social" }, "record" => { "text" => "hi" } }
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" },
      )

    data = described_class.fetch(at_uri: "at://alice.bsky.social/app.bsky.feed.post/xyz")

    expect(data).to be_ok
    expect(data.text_content).to eq("hi")
  end

  it "returns :unavailable (not :deleted) when a handle cannot be resolved" do
    stub_request(:get, "https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle")
      .with(query: { handle: "ghost.bsky.social" })
      .to_return(status: 400, body: "{}")
    # getPostThread must NOT be called with the unresolved handle URI (no stub for it).

    result = described_class.fetch(at_uri: "at://ghost.bsky.social/app.bsky.feed.post/xyz")

    expect(result.status).to eq(:unavailable)
  end

  describe ".canonical_at_uri" do
    let(:resolve_endpoint) { "https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle" }

    it "returns a DID-based URI unchanged (no resolution)" do
      uri = "at://did:plc:abc/app.bsky.feed.post/xyz"

      expect(described_class.canonical_at_uri(uri)).to eq(uri)
    end

    it "resolves a handle-based URI to its DID" do
      stub_request(:get, resolve_endpoint)
        .with(query: { handle: "alice.bsky.social" })
        .to_return(status: 200, body: { did: "did:plc:alice123" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = described_class.canonical_at_uri("at://alice.bsky.social/app.bsky.feed.post/xyz")

      expect(result).to eq("at://did:plc:alice123/app.bsky.feed.post/xyz")
    end

    it "falls back to the input when the handle cannot be resolved" do
      stub_request(:get, resolve_endpoint)
        .with(query: { handle: "alice.bsky.social" })
        .to_return(status: 400, body: "{}")
      uri = "at://alice.bsky.social/app.bsky.feed.post/xyz"

      expect(described_class.canonical_at_uri(uri)).to eq(uri)
    end
  end
end
