require "rails_helper"

RSpec.describe Igdb::Client do
  let(:token_url) { %r{\Ahttps://id\.twitch\.tv/oauth2/token} }
  let(:games_url) { "https://api.igdb.com/v4/games" }
  let(:game_json) do
    [{
      "id" => 119_388,
      "name" => "Hades II",
      "url" => "https://www.igdb.com/games/hades-ii",
      "first_release_date" => Time.zone.parse("2025-09-25").to_i,
      "cover" => { "image_id" => "co8wlg" },
      "artworks" => [{ "image_id" => "ar3abc" }],
      "platforms" => [{ "abbreviation" => "PC" }, { "name" => "Nintendo Switch 2" }]
    }]
  end

  before do
    Rails.cache.delete(described_class::TOKEN_CACHE_KEY)
    allow(Settings::General).to receive_messages(igdb_client_id: "client-id", igdb_client_secret: "secret")
    stub_request(:post, token_url).to_return(
      status: 200, body: { access_token: "token-1", expires_in: 5_000_000 }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  it "searches games and maps the result" do
    stub = stub_request(:post, games_url)
      .with(headers: { "Client-ID" => "client-id", "Authorization" => "Bearer token-1" },
            body: /search "Hades II";/)
      .to_return(status: 200, body: game_json.to_json, headers: { "Content-Type" => "application/json" })

    result = described_class.new.search("Hades II").first

    expect(stub).to have_been_requested
    expect(result.igdb_id).to eq(119_388)
    expect(result.title).to eq("Hades II")
    expect(result.release_year).to eq(2025)
    expect(result.platforms).to eq(["PC", "Nintendo Switch 2"])
    expect(result.cover_url).to eq("https://images.igdb.com/igdb/image/upload/t_cover_big/co8wlg.jpg")
    expect(result.artwork_url).to include("ar3abc")
  end

  it "escapes quotes and semicolons in the query" do
    stub = stub_request(:post, games_url).with(body: /search "Say \\"hi\\" there";/)
      .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })
    described_class.new.search('Say "hi"; there')
    expect(stub).to have_been_requested
  end

  it "refreshes the token once after a 401" do
    stub_request(:post, games_url)
      .to_return({ status: 401, body: "{}" },
                 { status: 200, body: game_json.to_json, headers: { "Content-Type" => "application/json" } })

    expect(described_class.new.search("Hades").size).to eq(1)
    expect(a_request(:post, token_url)).to have_been_made.twice
  end

  it "raises when credentials are missing" do
    allow(Settings::General).to receive(:igdb_client_secret).and_return(nil)
    expect { described_class.new.search("Hades") }.to raise_error(described_class::NotConfigured)
  end

  it "raises an Error on API failures" do
    stub_request(:post, games_url).to_return(status: 500, body: "")
    expect { described_class.new.search("Hades") }.to raise_error(described_class::Error)
  end
end
