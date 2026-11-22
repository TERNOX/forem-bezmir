require "open-uri"

# Fork-only: draws a ballot's "my picks" pictures in the site's dark theme
# (black page, grey-900 panels, the community's logo and brand colour).
#
# * :card    — 1080px wide vote card with every answered nomination: the
#              ranked one on top with its places, the rest as a two-column
#              list. Its height follows the number of answers.
# * :preview — 1200x630 link preview (og:image): the header and the featured
#              picks only, plus the number of answered nominations.
#
# Everything is composed by a single ImageMagick command, so a full card costs
# one process plus the cover downloads (fetched in parallel). Rows are built as
# small images and appended, because every composite onto the big canvas
# copies the whole canvas.
module Votings
  class ShareCard
    FONTS = { bold: "NotoSans-Bold.ttf", medium: "NotoSans-Medium.ttf" }.freeze

    # Crayons dark theme tokens (app/assets/stylesheets/themes/dark.css).
    PAGE_COLOR = "#000000".freeze        # --body-bg
    PANEL_COLOR = "#141311".freeze       # --card-bg / --header-bg (grey-900)
    BORDER_COLOR = "#2f2e2c".freeze      # --card-border (white 15%) over the panel
    TEXT_COLOR = "#f9f9f8".freeze        # --body-color (grey-50)
    SECONDARY_COLOR = "#bebbb4".freeze   # --card-color-tertiary (grey-400)
    THUMB_COLOR = "#262421".freeze       # grey-700
    FALLBACK_BRAND = "#3b49df".freeze

    CARD_WIDTH = 1080
    STORY_HEIGHT = 1920
    PREVIEW_SIZE = [1200, 630].freeze
    PAD = 56
    CONTENT_TOP = 288
    ROW_PITCH = 80
    THUMB = [48, 72].freeze
    FEATURED_COVER = [88, 132].freeze
    DOWNLOAD_TIMEOUT = 6
    DOWNLOAD_THREADS = 4

    ANCHORS = { top_left: "NorthWest", top_right: "NorthEast", bottom_left: "SouthWest",
                middle_left: "West", middle_right: "East", center: "Center" }.freeze

    def self.call(...)
      new(...).call
    end

    # @param layout [Symbol] :card or :preview
    # @param path [String] where to write the PNG
    def initialize(ballot:, picks:, layout:, path:)
      @voting = ballot.voting
      @user = ballot.user
      @picks = picks
      @layout = layout
      @path = path
      @tempfiles = []
      @files = {}
    end

    def call
      @featured = @picks.detect { |pick| pick.category.ranked? && pick.nominees.any? }
      @rest = @picks.reject { |pick| pick.equal?(@featured) }
      fetch_images
      args = @layout == :preview ? preview_args : card_args
      MiniMagick::Tool::Convert.new do |convert|
        args.each { |arg| convert << arg.to_s }
        convert << "PNG24:#{@path}"
      end
      @path
    ensure
      @tempfiles.each(&:close!)
    end

    private

    # --- vote card ---------------------------------------------------------

    def card_args
      width = CARD_WIDTH - (2 * PAD)
      rows = (@rest.size / 2.0).ceil
      featured_height = 52 + FEATURED_COVER[1] + 16
      list_top = CONTENT_TOP + (@featured ? featured_height + 16 : 0)
      list_height = (rows * ROW_PITCH) + 16
      content_bottom = rows.zero? ? list_top - 16 : list_top + list_height
      height = card_height(content_bottom + 108)

      canvas(CARD_WIDTH, height) do
        args = header_bar(96, 52, 24)
        title = @voting.title.to_s.squish
        args += place(label(title.truncate(34), :bold, title.size > 20 ? 48 : 60, TEXT_COLOR), PAD, 206,
                      anchor: :bottom_left)
        args += place(byline(44, 28), PAD, 242, anchor: :middle_left)
        if @featured
          args += panel(PAD, CONTENT_TOP, width, featured_height)
          args += place(featured_strip(width - 48), PAD + 24 - 12, CONTENT_TOP + 4)
        end
        if rows.positive?
          args += panel(PAD, list_top, width, list_height)
          column = (width - 48 - 24) / 2
          @rest.each_slice(rows).with_index do |picks, index|
            args += place(list_column(picks, column), PAD + 24 + (index * (column + 24)), list_top + 8)
          end
        end
        args + place(footer(28), PAD, height - 52, anchor: :bottom_left)
      end
    end

    # As tall as the answers need; a nearly full ballot lands exactly on the
    # 9:16 story size.
    def card_height(content)
      content.between?(STORY_HEIGHT - 240, STORY_HEIGHT) ? STORY_HEIGHT : content
    end

    # The ranked nomination: its title and up to three places side by side.
    # Drawn with a 12px margin so the place badges can stick out of the covers.
    def featured_strip(width)
      slot = width / 3
      cover_width, cover_height = FEATURED_COVER
      group(width + 24, 48 + cover_height + 12) do
        args = place(label(@featured.category.title.to_s.squish.truncate(48), :bold, 24, TEXT_COLOR), 12, 10)
        @featured.nominees.first(3).each_with_index do |nominee, index|
          left = 12 + (index * slot)
          args += place(cover(nominee, cover_width, cover_height, 6), left, 48)
          args += place(badge(index + 1, 32), left - 10, 38) if @featured.category.ranked?
          name = caption(nominee.display_title.to_s.squish.truncate(44), :bold, 22, TEXT_COLOR,
                         slot - cover_width - 32)
          args += place(name, left + cover_width + 16, 48 + (cover_height / 2), anchor: :middle_left)
        end
        args
      end
    end

    def list_column(picks, width)
      rows = picks.map do |pick|
        group(width, ROW_PITCH) do
          place(cover(pick.nominees.first, *THUMB, 4), 0, (ROW_PITCH - THUMB[1]) / 2) +
            place(pick_text(pick, width - THUMB[0] - 16), THUMB[0] + 16, ROW_PITCH / 2, anchor: :middle_left)
        end
      end
      ["("] + rows.flatten(1) + ["-background", "none", "-gravity", "NorthWest", "-append", ")"]
    end

    # Nomination (small, muted) above the pick (bold), as one block that is
    # centred on its row whether the pick takes one line or two.
    def pick_text(pick, width)
      names = pick.nominees.map { |nominee| nominee.display_title.to_s.squish }
      names << "«#{pick.other.to_s.squish}»" if pick.other.present?
      stack([label(pick.category.title.to_s.squish.truncate(40), :medium, 16, SECONDARY_COLOR),
             caption(names.join(", ").truncate(52), :bold, 22, TEXT_COLOR, width)],
            crop: [width, ROW_PITCH])
    end

    # --- link preview ------------------------------------------------------

    def preview_args
      width, height = PREVIEW_SIZE
      canvas(width, height) do
        args = header_bar(88, 44, 22)
        title = caption(@voting.title.to_s.squish.truncate(40), :bold, 54, TEXT_COLOR, 440)
        args += place(title, PAD, 312, anchor: :bottom_left)
        args += place(byline(44, 26), PAD, 354, anchor: :middle_left)
        args += place(footer(24), PAD, height - 44, anchor: :bottom_left)
        args += preview_tiles(552, 128)
        tiles = @featured ? 1 : [@rest.size, 3].min
        if @picks.size > tiles
          total = I18n.t("views.votings.share.image_total", count: @picks.size)
          args += place(label(total, :medium, 22, SECONDARY_COLOR), PAD, height - 44 - 32, anchor: :top_right)
        end
        args
      end
    end

    def preview_tiles(origin_x, origin_y)
      tiles = if @featured
                @featured.nominees.first(3).map { |nominee| [nominee, nil] }
              else
                @rest.filter_map { |pick| pick.nominees.first && [pick.nominees.first, pick.category.title] }.first(3)
              end
      args = []
      if @featured
        title = label(@featured.category.title.to_s.squish.truncate(36), :bold, 26, TEXT_COLOR)
        args += place(title, origin_x, origin_y)
      end
      tiles.each_with_index do |(nominee, heading), index|
        left = origin_x + (index * 208)
        args += place(cover(nominee, 176, 264, 10), left, origin_y + 48)
        args += place(badge(index + 1, 40), left - 12, origin_y + 36) if @featured&.category&.ranked?
        lines = []
        lines << label(heading.to_s.squish.truncate(20), :medium, 16, SECONDARY_COLOR) if heading
        lines << caption(nominee.display_title.to_s.squish.truncate(34), :bold, 19, TEXT_COLOR, 176)
        args += place(stack(lines, crop: [176, 74]), left, origin_y + 324)
      end
      args
    end

    # --- shared pieces -----------------------------------------------------

    # The site's top bar: logo on the left, address on the right.
    def header_bar(height, logo_height, text_size)
      rect(0, 0, @width, height, PANEL_COLOR) + rect(0, height, @width, height + 1, BORDER_COLOR) +
        place(logo(logo_height), PAD, height / 2, anchor: :middle_left) +
        place(label(URL.domain, :medium, text_size, SECONDARY_COLOR), PAD, height / 2, anchor: :middle_right)
    end

    def logo(height)
      file = @files[logo_url]
      return ["(", "#{file}[0]", "-resize", "#{height * 8}x#{height}", ")"] if file

      label(Settings::Community.community_name.to_s.squish.truncate(24), :bold, (height * 0.7).round, brand_color)
    end

    # Avatar and "Вибір @username" on one line.
    def byline(avatar, size)
      text = I18n.t("views.votings.share.image_byline", username: @user.username)
      row([picture(avatar_url, avatar, avatar, avatar / 2), spacer(16, 1), label(text, :medium, size, SECONDARY_COLOR)],
          gravity: "Center")
    end

    # "Голосуйте на <url>" with the address in the brand colour.
    def footer(size)
      marker = "\u0001"
      before, after = I18n.t("views.votings.share.image_footer", url: marker).split(marker, 2)
      gap = spacer((size * 0.28).round, 1) # label: drops the spaces around the address
      parts = []
      parts.push(label(before, :medium, size, SECONDARY_COLOR), gap) if before.present?
      parts << label("#{URL.domain}#{@voting.path}", :bold, size, brand_color)
      parts.push(gap, label(after, :medium, size, SECONDARY_COLOR)) if after.present?
      row(parts, gravity: "South")
    end

    # A nominee's picture; without one, a tile with its first letter (an
    # opening quote for a typed "other" answer, which has no nominee).
    def cover(nominee, width, height, radius)
      letter = nominee ? nominee.display_title.to_s[/[[:alnum:]]/].to_s.upcase : "“"
      picture(nominee&.image_url_for("cover"), width, height, radius, letter: letter)
    end

    def badge(number, size)
      half = size / 2
      group(size, size) do
        ["-fill", brand_color, "-stroke", PANEL_COLOR, "-strokewidth", "2",
         "-draw", "circle #{half},#{half} #{half},1", "-stroke", "none"] +
          place(label(number.to_s, :bold, (size * 0.56).round, "#ffffff"), half, half - 1, anchor: :center)
      end
    end

    # --- ImageMagick building blocks ----------------------------------------
    #
    # Every helper returns the arguments for one parenthesised image; #place
    # composes it onto the surface being drawn (the canvas or a #group).

    def canvas(width, height)
      @width = width
      @height = height
      # The hint lets libjpeg decode big covers at roughly the size they are shown.
      ["-define", "jpeg:size=352x528", "-size", "#{width}x#{height}", "xc:#{PAGE_COLOR}", "+size"] + yield
    end

    # A transparent surface of its own; #place calls inside the block are
    # relative to it.
    def group(width, height)
      outer = [@width, @height]
      @width = width
      @height = height
      ["(", "-size", "#{width}x#{height}", "xc:none", "+size"] + yield + [")"]
    ensure
      @width, @height = outer
    end

    def rect(left, top, right, bottom, color)
      ["-fill", color, "-stroke", "none", "-draw", "rectangle #{left},#{top} #{right - 1},#{bottom - 1}"]
    end

    def panel(left, top, width, height)
      ["-fill", PANEL_COLOR, "-stroke", BORDER_COLOR, "-strokewidth", "1",
       "-draw", "roundrectangle #{left},#{top} #{left + width - 1},#{top + height - 1} 12,12", "-stroke", "none"]
    end

    def label(text, font, size, color)
      ["(", "-background", "none", "-fill", color, "-font", font_path(font), "-pointsize", size, "+size",
       "label:#{escape(text)}", ")"]
    end

    # Text wrapped at +width+ pixels, with tighter lines than the font's own.
    # The tightening also eats into the last line, so that much is added back
    # under it (or descenders get cut).
    def caption(text, font, size, color, width)
      # Too short to wrap even in the widest glyphs: label: is much cheaper.
      return label(text, font, size, color) if text.to_s.size * size * 0.95 <= width

      tighten = (size * 0.18).round
      ["(", "-background", "none", "-fill", color, "-font", font_path(font), "-pointsize", size,
       "-interline-spacing", -tighten, "-gravity", "NorthWest", "-size", "#{width}x",
       "caption:#{escape(text)}", "+size", "-interline-spacing", "0",
       "-gravity", "South", "-splice", "0x#{tighten}", "-gravity", "NorthWest", ")"]
    end

    def spacer(width, height)
      ["(", "-size", "#{width}x#{height}", "xc:none", "+size", ")"]
    end

    # Images side by side.
    def row(images, gravity:)
      ["("] + images.flatten(1) + ["-background", "none", "-gravity", gravity, "+append", "-gravity", "NorthWest", ")"]
    end

    # Images one under another, left aligned, cut to +crop+ if they outgrow it.
    def stack(images, crop:)
      ["("] + images.flatten(1) +
        ["-background", "none", "-gravity", "NorthWest", "-append",
         "-crop", "#{crop[0]}x#{crop[1]}+0+0", "+repage", ")"]
    end

    # A cropped picture with rounded corners; when there is none, a plain tile
    # with +letter+ on it.
    def picture(url, width, height, radius, letter: nil)
      file = @files[url]
      source = if file
                 ["#{file}[0]", "-auto-orient", "-resize", "#{width}x#{height}^", "-gravity", "Center",
                  "-extent", "#{width}x#{height}", "-gravity", "NorthWest"]
               else
                 blank_tile(width, height, letter)
               end
      mask = ["(", "-size", "#{width}x#{height}", "xc:none", "+size", "-fill", "#ffffff", "-stroke", "none",
              "-draw", "roundrectangle 0,0 #{width - 1},#{height - 1} #{radius},#{radius}", ")"]
      ["("] + source + ["-alpha", "set"] + mask + ["-compose", "DstIn", "-composite", "-compose", "Over", ")"]
    end

    def blank_tile(width, height, letter)
      tile = ["-size", "#{width}x#{height}", "xc:#{THUMB_COLOR}", "+size"]
      return tile if letter.blank?

      tile + label(letter, :bold, (width * 0.5).round, SECONDARY_COLOR) +
        ["-compose", "Over", "-gravity", "Center", "-composite", "-gravity", "NorthWest"]
    end

    # Composes +image+ onto the current surface. +left+,+top+ is where its
    # +anchor+ point goes; for the right-hand anchors +left+ is the distance
    # from the right edge, for :bottom_left +top+ is the line its bottom sits
    # on. The :middle_* anchors centre the image on the line +top+, so text
    # blocks of different heights line up with the picture next to them.
    def place(image, left, top, anchor: :top_left)
      offset = case anchor
               when :bottom_left then format("+%<x>d+%<y>d", x: left, y: @height - top)
               when :middle_left, :middle_right then format("+%<x>d%<y>+d", x: left, y: top - (@height / 2))
               when :center then format("%<x>+d%<y>+d", x: left - (@width / 2), y: top - (@height / 2))
               else format("+%<x>d+%<y>d", x: left, y: top)
               end
      image + ["-compose", "Over", "-gravity", ANCHORS.fetch(anchor), "-geometry", offset, "-composite",
               "-gravity", "NorthWest"]
    end

    # User-provided text goes through label:/caption: (never -draw). A leading
    # "@" would read a file and "%" expands image properties, so both are
    # escaped; backslashes (escape sequences) and emoji (no glyphs in the
    # font) are dropped.
    def escape(text)
      clean = text.to_s.unicode_normalize(:nfkc).gsub(/[\p{Extended_Pictographic}\u{FE0F}\u{200D}\\]/, "").squish
      clean = " " if clean.blank?
      clean.gsub(/[@%]/, "@" => "\\@", "%" => "\\%")
    end

    def brand_color
      @brand_color ||= begin
        color = Settings::UserExperience.primary_brand_color_hex.to_s
        color.match?(/\A#\h{6}\z/) ? color : FALLBACK_BRAND
      end
    end

    # ImageMagick opens the font again for every piece of text. A copy in the
    # temp dir keeps that fast when the app directory is a slow mount.
    def font_path(font)
      @font_paths ||= {}
      @font_paths[font] ||= begin
        name = FONTS.fetch(font)
        source = Rails.root.join("app/assets/fonts", name)
        copy = File.join(Dir.tmpdir, "voting-card-#{File.size(source)}-#{name}")
        FileUtils.cp(source, copy) unless File.exist?(copy)
        copy
      rescue SystemCallError
        source.to_s
      end
    end

    # --- images -------------------------------------------------------------

    def logo_url
      @logo_url ||= (Settings::General.resized_logo.presence || Settings::General.original_logo.presence).to_s
    end

    def avatar_url
      @avatar_url ||= @user.profile_image_url_for(length: 96).to_s
    end

    def image_urls
      nominees = if @layout == :preview
                   @featured ? @featured.nominees.first(3) : @rest.filter_map { |pick| pick.nominees.first }.first(3)
                 else
                   @rest.filter_map { |pick| pick.nominees.first } + @featured&.nominees.to_a.first(3)
                 end
      ([logo_url, avatar_url] + nominees.map { |nominee| nominee.image_url_for("cover") }).compact_blank.uniq
    end

    # Sources are resolved here (that can read settings); the threads only do
    # file and network I/O.
    def fetch_images
      queue = Queue.new
      image_urls.each { |url| queue << [url, source_for(url)] }
      mutex = Mutex.new
      Array.new([DOWNLOAD_THREADS, queue.size].min) do
        Thread.new do
          loop do
            url, source = queue.pop(true)
            file = fetch(source)
            mutex.synchronize { @files[url] = file }
          rescue ThreadError
            break
          end
        end
      end.each(&:join)
    end

    # Accepts absolute URLs (IGDB CDN, S3) and local "/uploads/..." paths.
    # @return [String, nil] a local file path or an absolute http(s) URL
    def source_for(url)
      return (url if url.start_with?("http")) unless url.start_with?("/")

      path = Rails.public_path.join(url.delete_prefix("/").split("?").first).to_s
      File.file?(path) ? path : URL.url(url)
    end

    # @return [String, nil] a readable local image file
    def fetch(source)
      return if source.blank?
      return (source if readable_image?(source)) unless source.start_with?("http")

      file = Tempfile.new(["voting_card", File.extname(URI.parse(source).path).presence || ".jpg"])
      @tempfiles << file
      URI.open(source, read_timeout: DOWNLOAD_TIMEOUT, open_timeout: DOWNLOAD_TIMEOUT) do |remote| # rubocop:disable Security/Open
        file.binmode
        IO.copy_stream(remote, file)
      end
      file.flush
      file.path if readable_image?(file.path)
    rescue StandardError => e
      Rails.logger.warn("[Votings::ShareCard] could not load #{source}: #{e.class}")
      nil
    end

    # One unreadable cover must not fail the whole card.
    def readable_image?(path)
      MiniMagick::Image.new(path).valid?
    end
  end
end
