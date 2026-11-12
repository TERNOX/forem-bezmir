require "rails_helper"

RSpec.describe SocialAutopost::TelegramClient do
  let(:client) { described_class.new(token: "123:abc", chat_id: "-100123") }
  let(:api) { "https://api.telegram.org/bot123:abc" }

  it "sends a plain-text message with a large link preview" do
    preview = { "url" => "https://kutok.io/a", "prefer_large_media" => true }
    request = stub_request(:post, "#{api}/sendMessage")
      .with(body: hash_including("chat_id" => "-100123", "text" => "Hello", "link_preview_options" => preview))
      .to_return(status: 200, body: { ok: true, result: { message_id: 77 } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(client.send_message("Hello", link_url: "https://kutok.io/a", disable_preview: false)).to eq("77")
    expect(request).to have_been_requested
  end

  it "raises with Telegram's description and code" do
    stub_request(:post, "#{api}/sendMessage")
      .to_return(status: 400, body: { ok: false, error_code: 400, description: "Bad Request: chat not found" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect { client.send_message("Hi", disable_preview: true) }.to raise_error(described_class::Error) { |error|
      expect(error.message).to include("chat not found")
      expect(error.message).not_to include("123:abc")
      expect(error).to be_setup_problem
    }
  end

  it "treats other bad requests as a problem with the message" do
    error = described_class::Error.new("Bad Request: message is too long", code: 400)
    expect(error).not_to be_setup_problem
  end

  it "checks the bot's rights in the channel without posting" do
    stub_request(:post, "#{api}/getMe")
      .to_return(body: { ok: true, result: { id: 5, username: "kutok_bot" } }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:post, "#{api}/getChat")
      .to_return(body: { ok: true, result: { title: "Куток закритий" } }.to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:post, "#{api}/getChatMember")
      .to_return(body: { ok: true, result: { status: "administrator", can_post_messages: true } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect(client.check).to eq(bot: "@kutok_bot", chat: "Куток закритий", can_post: true)
    expect(a_request(:post, "#{api}/sendMessage")).not_to have_been_made
  end
end
