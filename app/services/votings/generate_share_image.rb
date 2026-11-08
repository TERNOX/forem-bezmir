require "open-uri"

# Fork-only: renders the 1200x630 "my picks" card for a ballot (used as the
# share page's og:image and as the downloadable picture).
#
# Layout: header (voting title, "@username's picks", community name); on the
# left the featured nomination (the first ranked one, else the first answered)
# with big covers and place badges; on the right a grid with the first pick of
# every other answered nomination.
module Votings
  class GenerateShareImage
    WIDTH = 1200
    HEIGHT = 630
    MARGIN = 60
    BOLD_FONT = Rails.root.join("app/assets/fonts/NotoSans-Bold.ttf").to_s
    MEDIUM_FONT = Rails.root.join("app/assets/fonts/NotoSans-Medium.ttf").to_s
    TEXT_COLOR = "#f5f6f8".freeze
    MUTED_COLOR = "#9aa3b2".freeze
    ACCENT_COLOR = "#f5b301".freeze
    PLACEHOLDER_COLOR = "#2a2f3d".freeze
    FEATURED_SIZE = [150, 225].freeze
    # Right-hand grid: bigger covers when there are fewer picks to show.
    GRID_LAYOUTS = [
      { max: 3, size: [150, 225], columns: 3, gap: 20, titles: true },
      { max: 8, size: [100, 150], columns: 4, gap: 14, titles: false },
      { max: 18, size: [80, 120], columns: 6, gap: 14, titles: false },
    ].freeze
    WIDE_GRID_LAYOUTS = [
      { max: 6, size: [150, 225], columns: 6, gap: 26, titles: true },
      { max: 20, size: [100, 150], columns: 10, gap: 8, titles: false },
    ].freeze
    GAP = 14
    DOWNLOAD_TIMEOUT = 6
    # One render per ballot at a time, shared by the worker and the on-demand
    # image endpoint. Covers are downloaded with DOWNLOAD_TIMEOUT each, so a
    # render stays well under LOCK_TTL. A failed render keeps the key for a
    # short cooldown so a known share URL can't be used to retry it in a loop.
    LOCK_TTL = 5.minutes
    FAILURE_COOLDOWN = 1.minute

    def self.call(ballot)
      new(ballot).call
    end

    def self.lock_key(ballot)
      "voting-share-image:#{ballot.id}"
    end

    def initialize(ballot)
      @ballot = ballot
      @revision = ballot.submitted_at
      @voting = ballot.voting
      @user = ballot.user
      @tempfiles = []
    end

    # @return [Boolean] whether this call drew the image (false: another render
    # holds the lock, it is cooling down after a failure, or it went stale).
    def call
      key = self.class.lock_key(@ballot)
      owner = SecureRandom.hex(8)
      return false unless Rails.cache.write(key, owner, unless_exist: true, expires_in: LOCK_TTL)

      begin
        stored = I18n.with_locale(locale) { render }
        release(key, owner)
        stored
      rescue StandardError
        Rails.cache.write(key, "failed", expires_in: FAILURE_COOLDOWN) if Rails.cache.read(key) == owner
        raise
      end
    ensure
      @tempfiles.each { |file| file.close! }
    end

    private

    # Only drop the lock if it is still ours (it may have expired and been
    # taken by another render meanwhile).
    def release(key, owner)
      Rails.cache.delete(key) if Rails.cache.read(key) == owner
    end

    # Workers run without a request locale; use the community's language.
    def locale
      candidate = Settings::UserExperience.default_locale.presence&.to_sym
      I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
    end

    def render
      picks = Votings::BallotPicks.call(@ballot)
      featured = picks.detect { |pick| pick.category.ranked? && pick.nominees.any? } ||
        picks.detect { |pick| pick.nominees.any? }
      others = picks.reject { |pick| pick.equal?(featured) }.filter_map { |pick| pick.nominees.first }

      image = background
      image = draw_header(image)
      image = draw_featured(image, featured) if featured
      image = draw_grid(image, others, featured ? 600 : MARGIN)
      image = draw_footer(image)
      store(image)
    end

    def background
      file = tempfile(".png")
      MiniMagick::Tool::Convert.new do |convert|
        convert.size "#{WIDTH}x#{HEIGHT}"
        convert << "gradient:#1d2233-#0b0d14"
        convert << file.path
      end
      MiniMagick::Image.new(file.path)
    end

    def draw_header(image)
      image = overlay_text(image, truncate(@voting.title, 42), BOLD_FONT, 40, TEXT_COLOR, MARGIN, 44)
      byline = I18n.t("views.votings.share.image_byline", username: @user.username)
      image = overlay_text(image, byline, MEDIUM_FONT, 24, MUTED_COLOR, MARGIN, 104)
      community = truncate(Settings::Community.community_name.to_s, 30)
      label = render_text(community, MEDIUM_FONT, 22, ACCENT_COLOR)
      composite(image, label, WIDTH - MARGIN - label.width, 52)
    end

    def draw_featured(image, pick)
      image = overlay_text(image, truncate(pick.category.title, 30), BOLD_FONT, 24, ACCENT_COLOR, MARGIN, 168)
      width, height = FEATURED_SIZE
      pick.nominees.first(3).each_with_index do |nominee, index|
        x = MARGIN + (index * (width + 20))
        image = draw_cover(image, nominee, x, 214, width, height)
        image = draw_badge(image, (index + 1).to_s, x + 8, 222) if pick.category.ranked?
        image = overlay_text(image, truncate(nominee.display_title, 16), MEDIUM_FONT, 17, TEXT_COLOR, x,
                             214 + height + 10)
      end
      image
    end

    def draw_grid(image, nominees, left)
      return image if nominees.empty?

      layouts = left == MARGIN ? WIDE_GRID_LAYOUTS : GRID_LAYOUTS
      layout = layouts.detect { |l| nominees.size <= l[:max] } || layouts.last
      width, height = layout[:size]
      label = I18n.t("views.votings.share.image_more_picks")
      image = overlay_text(image, label, BOLD_FONT, 24, ACCENT_COLOR, left, 168)
      nominees.first(layout[:max]).each_with_index do |nominee, index|
        x = left + ((index % layout[:columns]) * (width + layout[:gap]))
        y = 214 + ((index / layout[:columns]) * (height + layout[:gap]))
        image = draw_cover(image, nominee, x, y, width, height)
        if layout[:titles]
          image = overlay_text(image, truncate(nominee.display_title, 16), MEDIUM_FONT, 17, TEXT_COLOR, x,
                               y + height + 10)
        end
      end
      image
    end

    def draw_footer(image)
      text = I18n.t("views.votings.share.image_footer", url: "#{URL.domain}#{@voting.path}")
      overlay_text(image, text, MEDIUM_FONT, 20, MUTED_COLOR, MARGIN, HEIGHT - 50)
    end

    def draw_cover(image, nominee, x, y, width, height)
      source = load_image(nominee.image_url_for("cover"))
      cover = if source
                source.combine_options do |c|
                  c.resize "#{width}x#{height}^"
                  c.gravity "center"
                  c.extent "#{width}x#{height}"
                end
                source
              else
                placeholder(width, height)
              end
      composite(image, cover, x, y)
    end

    def draw_badge(image, text, x, y)
      file = tempfile(".png")
      MiniMagick::Tool::Convert.new do |convert|
        convert.size "34x34"
        convert << "xc:none"
        convert.fill ACCENT_COLOR
        convert.draw "circle 17,17 17,1"
        convert << file.path
      end
      badge = composite(image, MiniMagick::Image.new(file.path), x, y)
      digit = render_text(text, BOLD_FONT, 20, "#111111")
      composite(badge, digit, x + 17 - (digit.width / 2), y + 17 - (digit.height / 2))
    end

    def placeholder(width, height)
      file = tempfile(".png")
      MiniMagick::Tool::Convert.new do |convert|
        convert.size "#{width}x#{height}"
        convert << "xc:#{PLACEHOLDER_COLOR}"
        convert << file.path
      end
      MiniMagick::Image.new(file.path)
    end

    def overlay_text(image, text, font, size, color, x, y)
      composite(image, render_text(text, font, size, color), x, y)
    end

    # User-provided text goes through label: (never -draw), escaped like the
    # social image generator does, so "@" and "%" are literal.
    def render_text(text, font, size, color)
      file = tempfile(".png")
      content = clean(text).presence || " "
      MiniMagick::Tool::Convert.new do |convert|
        convert.background "none"
        convert.fill color
        convert.font font
        convert.pointsize size.to_s
        convert << "label:#{escape(content)}"
        convert << file.path
      end
      MiniMagick::Image.new(file.path)
    end

    def composite(base, overlay, x, y)
      base.composite(overlay) do |c|
        c.compose "Over"
        c.geometry "+#{x.to_i}+#{y.to_i}"
      end
    end

    # Accepts absolute URLs (IGDB CDN, S3) and local "/uploads/..." paths.
    def load_image(url)
      return if url.blank?

      if url.start_with?("/")
        path = Rails.public_path.join(url.delete_prefix("/").split("?").first)
        return MiniMagick::Image.open(path.to_s) if File.exist?(path)

        url = URL.url(url)
      end
      return unless url.start_with?("http")

      file = tempfile(File.extname(URI.parse(url).path).presence || ".jpg")
      URI.open(url, read_timeout: DOWNLOAD_TIMEOUT, open_timeout: DOWNLOAD_TIMEOUT) do |remote| # rubocop:disable Security/Open
        file.binmode
        IO.copy_stream(remote, file)
      end
      file.flush
      MiniMagick::Image.open(file.path).tap { |img| img.format("png") }
    rescue StandardError => e
      Rails.logger.warn("[Votings::GenerateShareImage] could not load #{url}: #{e.class}")
      nil
    end

    def store(image)
      image.format("png")
      file = tempfile(".png")
      image.write(file.path)
      @ballot.with_lock do
        # The voter changed their picks while we were drawing: a newer render
        # (queued by that submission) owns the image, so drop this stale one.
        # Compared at the database's microsecond precision.
        next false if @ballot.submitted_at&.floor(6) != @revision&.floor(6)

        @ballot.share_image = File.open(file.path)
        @ballot.save!
        true
      end
    end

    def tempfile(ext)
      Tempfile.new(["voting_share", ext]).tap { |file| @tempfiles << file }
    end

    def truncate(text, length)
      text.to_s.squish.truncate(length)
    end

    def clean(text)
      text.to_s.unicode_normalize(:nfkc).gsub(/[\p{Extended_Pictographic}️‍]/, "").squish
    end

    def escape(text)
      text.gsub(/[\\"@%]/, "\\" => "\\\\", '"' => '\\"', "@" => "\\@", "%" => "\\%")
    end
  end
end
