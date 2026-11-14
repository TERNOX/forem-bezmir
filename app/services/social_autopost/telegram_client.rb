module SocialAutopost
  # Minimal Telegram Bot API client: sends plain-text channel posts.
  class TelegramClient
    API_URL = "https://api.telegram.org".freeze
    TIMEOUT = 15
    # "<bot id>:<secret>" as issued by @BotFather.
    TOKEN_FORMAT = /\A\d+:[A-Za-z0-9_-]+\z/
    # A numeric chat id (-100… for channels) or a public @channelusername.
    CHAT_ID_FORMAT = /\A(-?\d+|@[A-Za-z0-9_]{4,})\z/

    class Error < StandardError
      attr_reader :code, :retry_after

      def initialize(message, code: nil, retry_after: nil)
        super(message)
        @code = code
        @retry_after = retry_after
      end

      # Problems with the bot or channel setup (or Telegram itself) rather than
      # with one message: the item stays queued and is retried later.
      def setup_problem?
        code.nil? || code == 401 || code == 403 || code == 404 || code == 429 || code >= 500 ||
          message.match?(/chat not found|bot was kicked|not enough rights|need administrator rights/i)
      end
    end

    def initialize(token: Settings::SocialAutopost.telegram_bot_token,
                   chat_id: Settings::SocialAutopost.telegram_chat_id)
      @token = token.to_s.strip
      @chat_id = chat_id.to_s.strip
    end

    # @return [String] the id of the sent message
    def send_message(text, link_url: nil, disable_preview: Settings::SocialAutopost.disable_link_preview)
      preview = if disable_preview
                  { is_disabled: true }
                else
                  { url: link_url, prefer_large_media: true }.compact
                end

      result = call("sendMessage", chat_id: chat_id, text: text, link_preview_options: preview)
      result["message_id"].to_s
    end

    # Checks the token and the bot's access to the channel without posting.
    # @return [Hash] { bot: "@name", chat: "Title", can_post: true/false }
    def check
      bot = call("getMe")
      chat = call("getChat", chat_id: chat_id)
      member = call("getChatMember", chat_id: chat_id, user_id: bot["id"])
      can_post = member["status"] == "creator" ||
        (member["status"] == "administrator" && member.fetch("can_post_messages", true))
      { bot: "@#{bot['username']}", chat: chat["title"] || chat["username"], can_post: can_post }
    end

    private

    attr_reader :token, :chat_id

    def call(method, **params)
      raise Error, "Telegram bot token is not set" if token.blank?
      raise Error, "The saved bot token is not a @BotFather token (digits:letters). Paste it again." unless
        token.match?(TOKEN_FORMAT)

      response = HTTParty.post(
        "#{API_URL}/bot#{token}/#{method}",
        body: params.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: TIMEOUT,
      )
      body = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
      return body["result"] if response.success? && body["ok"]

      raise Error.new(
        "Telegram #{method} failed: #{body['description'] || "HTTP #{response.code}"}",
        code: body["error_code"] || response.code,
        retry_after: body.dig("parameters", "retry_after"),
      )
    rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
           Errno::ECONNRESET, OpenSSL::SSL::SSLError => e
      raise Error, "Telegram #{method} failed: #{e.class}"
    end
  end
end
