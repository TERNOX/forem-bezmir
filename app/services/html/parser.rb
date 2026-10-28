module Html
  class Parser
    ALERT_TYPES = %w[note tip important warning caution].freeze
    # The marker must be followed by whitespace or the end of the text node, so
    # `[!NOTE]worthy` stays an ordinary blockquote.
    ALERT_TOKEN = /\A\[!(#{ALERT_TYPES.join('|')})\](?=\s|\z)\s*/i

    # Each of the instance methods should return self to support chaining of
    # methods
    # For example:
    #  Html::Parser.
    #    new(html).
    #    remove_nested_linebreak_in_list.
    #    prefix_all_images.
    #    wrap_all_images_in_links.
    #    html

    include InlineSvg::ActionView::Helpers
    include ApplicationHelper

    RAW_TAG_DELIMITERS = ["{", "}", "raw", "endraw", "----"].freeze
    RAW_TAG = "{----% raw %----}".freeze
    END_RAW_TAG = "{----% endraw %----}".freeze
    MARKDOWN_VIDEO_PATTERN = /\.(mp4|webm|mov|m4v)\z/i.freeze
    DEFAULT_IMAGE_CAPTIONS = ["Image description", "Опис картинки"].freeze

    attr_accessor :html
    private :html=

    def initialize(html)
      @html = html
    end

    def remove_nested_linebreak_in_list
      html_doc = Nokogiri::HTML(@html)
      html_doc.xpath("//*[self::ul or self::ol or self::li]/br").each(&:remove) if @html&.match?(/<br/i)
      @html = html_doc.to_html

      self
    end

    def convert_markdown_videos
      fragment = Nokogiri::HTML.fragment(@html)
      document = fragment.document || Nokogiri::HTML::Document.parse("")

      fragment.css("img").each do |image|
        src = image.attr("src")
        next unless src&.match?(MARKDOWN_VIDEO_PATTERN)

        container = image.parent.name == "a" ? image.parent : image
        figure = document.create_element("figure")
        figure["class"] = "article-body__video"

        video = document.create_element("video")
        video["class"] = "article-body__video-player"
        video["controls"] = "controls"
        video["playsinline"] = "playsinline"
        video["preload"] = "metadata"
        video["data-video-player"] = "markdown-embedded"
        video["src"] = src

        alt_text = image.attr("alt").to_s.strip
        video["aria-label"] = alt_text if alt_text.present?

        unless video.children.any?
          fallback = document.create_element("span")
          fallback["class"] = "sr-only"
          fallback.content = I18n.t("services.html.parser.unsupported_video")
          video.add_child(fallback)
        end

        figure.add_child(video)

        parent = container.parent
        if parent&.name == "p"
          significant_children = parent.children.reject do |child|
            child.text? && child.content.strip.empty?
          end

          if significant_children.one? && significant_children.first == container
            parent.replace(figure)
            next
          end
        end

        container.replace(figure)
      end

      @html = fragment.to_html

      self
    end

    def prefix_all_images(width: 1500, synchronous_detail_detection: false, quality: "auto")
      # wrap with Cloudinary or allow if from giphy or githubusercontent.com
      doc = Nokogiri::HTML.fragment(@html)

      if @html&.match?(/<img/i)
        doc.css("img").each do |img|
          src = img.attr("src")
          next unless src
          # allow image to render as-is
          next if allowed_image_host?(src)
          next if img["data-ignore-prefix"] == "true"

          if synchronous_detail_detection
            header = { "User-Agent" => "#{Settings::Community.community_name} (#{URL.url})" }
            img["width"], img["height"] = FastImage.size(src, timeout: 10, http_header: header)
          end

          img["loading"] = "lazy"
          img["src"] = if Giphy::Image.valid_url?(src)
                         src.gsub("https://media.", "https://i.")
                       else
                         img_of_size(src, width, quality: quality)
                       end
        end
      end

      @html = doc.to_html

      self
    end

    def wrap_all_images_in_links
      return self if @html.blank? || !@html.match?(/<img/i)

      doc = Nokogiri::HTML.fragment(@html)

      doc.search("p img").each do |image|
        next if image.parent.name == "a"

        link = doc.document.create_element("a")
        link["href"] = image.attr("src").to_s
        link["class"] = "article-body-image-wrapper"
        image.replace(link)
        link.add_child(image)
      end

      @html = doc.to_html

      self
    end

    def transform_markdown_alerts
      doc = Nokogiri::HTML.fragment(@html)

      doc.css("blockquote").each do |blockquote|
        first = blockquote.element_children.first
        next unless first&.name == "p"

        leading = first.children.first
        next unless leading&.text?

        match = leading.content.match(ALERT_TOKEN)
        next unless match

        alert_type = match[1].downcase
        strip_alert_token(first)

        blockquote["data-alert"] = alert_type
        blockquote.prepend_child(alert_label_node(doc, alert_type))
      end

      @html = doc.to_html

      self
    end

    def add_figcaptions_to_images
      return self if @html.blank?

      fragment = Nokogiri::HTML.fragment(@html)

      fragment.css("a.article-body-image-wrapper > img").each do |image|
        caption_text = sanitized_caption_text(image)
        next if caption_text.blank?

        link = image.parent
        figure = link.ancestors("figure").first || build_figure_for(link)
        next unless figure
        next if figure.at_css("figcaption")

        figcaption = Nokogiri::XML::Node.new("figcaption", fragment.document)
        figcaption.content = caption_text
        figure.add_child(figcaption)
      end

      @html = fragment.to_html

      self
    end

    def add_control_class_to_codeblock
      return self if @html.blank? || !may_contain?("highlight")

      doc = Nokogiri::HTML.fragment(@html)

      doc.search("div.highlight").each do |codeblock|
        codeblock.add_class("js-code-highlight")
      end

      @html = doc.to_html

      self
    end

    def add_control_panel_to_codeblock
      return self if @html.blank? || !may_contain?("highlight")

      doc = Nokogiri::HTML.fragment(@html)

      doc.search("div.highlight").each do |codeblock|
        codeblock.add_child('<div class="highlight__panel js-actions-panel"></div>')
      end

      @html = doc.to_html

      self
    end

    def add_fullscreen_button_to_panel
      return self if @html.blank? || !may_contain?("highlight__panel")

      on_title = I18n.t("services.html.parser.enter_fullscreen_mode")
      on_cls = "highlight-action crayons-icon highlight-action--fullscreen-on"
      icon_fullscreen_on = inline_svg_tag(
        "fullscreen-on.svg", class: on_cls, title: on_title, width: "20px", height: "20px"
      )
      off_title = I18n.t("services.html.parser.exit_fullscreen_mode")
      off_cls = "highlight-action crayons-icon highlight-action--fullscreen-off"
      icon_fullscreen_off = inline_svg_tag(
        "fullscreen-off.svg", class: off_cls, title: off_title, width: "20px", height: "20px"
      )
      doc = Nokogiri::HTML.fragment(@html)
      doc.search("div.highlight__panel").each do |codeblock|
        fullscreen_action = <<~HTML
          <div class="highlight__panel-action js-fullscreen-code-action">
              #{icon_fullscreen_on}
              #{icon_fullscreen_off}
          </div>
        HTML

        codeblock.add_child(fullscreen_action)
      end

      @html = doc.to_html

      self
    end

    def wrap_all_tables
      return self if @html.blank? || !@html.match?(/<table/i)

      doc = Nokogiri::HTML.fragment(@html)
      doc.search("table").each { |table| table.swap("<div class='table-wrapper-paragraph'>#{table}</div>") }
      @html = doc.to_html

      self
    end

    def remove_empty_paragraphs
      return self if @html.blank? || !@html.match?(/<p/i)

      doc = Nokogiri::HTML.fragment(@html)
      doc.css("p").select { |paragraph| all_children_are_blank?(paragraph) }.each(&:remove)
      @html = doc.to_html

      self
    end

    def escape_colon_emojis_in_codeblock
      html_doc = Nokogiri::HTML.fragment(@html)

      html_doc.children.each do |el|
        next if el.name == "code"

        if el.search("code").empty?
          if el.parent.present?
            parsed_html = Html::Parser.new(el.to_html).parse_emojis.html
            el.swap(parsed_html)
          end
        else
          el.children = self.class.new(el.children.to_html)
            .escape_colon_emojis_in_codeblock
            .html
        end
      end

      @html = html_doc.to_html

      self
    end

    def unescape_raw_tag_in_codeblocks
      return self if @html.blank?

      @html.gsub!(RAW_TAG, "{% raw %}")
      @html.gsub!(END_RAW_TAG, "{% endraw %}")
      html_doc = Nokogiri::HTML(@html)
      html_doc.xpath("//body/div/pre/code").each do |codeblock|
        next unless codeblock.content.include?(RAW_TAG) || codeblock.content.include?(END_RAW_TAG)

        children_content = codeblock.children.map(&:content)
        indices = children_content.size.times.select do |i|
          possibly_raw_tag_syntax?(children_content[i..i + 2])
        end
        indices.each do |i|
          codeblock.children[i].content = codeblock.children[i].content.delete("----")
        end
      end

      body = html_doc.at_css("body")
      @html = body ? body.inner_html : html_doc.to_html

      self
    end

    def wrap_all_figures_with_tags
      return self if @html.blank? || !@html.match?(/<figcaption/i)

      html_doc = Nokogiri::HTML(@html)

      html_doc.xpath("//figcaption").each do |caption|
        next if caption.parent.name == "figure"
        next unless caption.previous_element

        fig = html_doc.create_element "figure"
        prev = caption.previous_element
        prev.replace(fig) << prev << caption
      end

      body = html_doc.at_css("body")
      @html = body ? body.inner_html : html_doc.to_html

      self
    end

    def wrap_mentions_with_links
      return self if @html.blank? || !may_contain?("@")

      html_doc = Nokogiri::HTML(@html)

      # looks for nodes that isn't <code>, <a>, and contains "@"
      targets = html_doc.xpath('//html/body/*[not (self::code) and not(self::a) and contains(., "@")]').to_a

      # A Queue system to look for and replace possible usernames
      until targets.empty?
        node = targets.shift

        # only focus on portion of text with "@"
        node.xpath("text()[contains(.,'@')]").each do |el|
          el.replace(el.to_s.gsub(/\B@[a-z0-9_-]+/i) { |text| user_link_if_exists(text) })
        end

        # enqueue children that has @ in it's text
        children = node.xpath('*[not(self::code) and not(self::a) and contains(., "@")]').to_a
        targets.concat(children)
      end

      body = html_doc.at_css("body")
      @html = body ? body.inner_html : html_doc.to_html

      self
    end

    def parse_emojis
      return self if @html.blank?

      @html.gsub!(/:([\w+-]+):/) do |match|
        emoji = Emoji.find_by_alias(Regexp.last_match(1)) # rubocop:disable Rails/DynamicFindBy
        emoji.present? ? emoji.raw : match
      end

      self
    end

    def enforce_gif_like_videos
      return self if @html.blank? || !@html.match?(/<video/i)

      doc = Nokogiri::HTML.fragment(@html)

      doc.css("video").each do |video|
        next if video["data-video-player"].present?

        # Mark as gif-like for JS to attach behavior
        video["data-gif-video"] = "true"
        # Default attributes to mimic GIF behavior, unless explicitly overridden
        video["autoplay"] = video["autoplay"] || "autoplay"
        video["loop"] = video["loop"] || "loop"
        video["muted"] = video["muted"] || "muted"
        video["playsinline"] = video["playsinline"] || "playsinline"
        # Remove controls by default unless explicitly present
        video.remove_attribute("controls") unless video["controls"]
        # Avoid preloading to save bandwidth if not provided
        video["preload"] = video["preload"] || "metadata"
      end

      @html = doc.to_html

      self
    end

    def normalize_youtube_embed_domains
      @html = YoutubeUrl.normalize_embed_html(@html)
      self
    end

    private

    # Literal-substring fast-exit guard. Any "&" means the marker may be spelled with
    # character references (e.g. "&#64;" or "high&#108;ight") that Nokogiri decodes,
    # so fall through to the full parse in that case.
    def may_contain?(marker)
      @html.include?(marker) || @html.include?("&")
    end

    def strip_alert_token(paragraph)
      text_node = paragraph.children.detect { |child| child.text? && child.content.match?(ALERT_TOKEN) }
      return unless text_node

      text_node.content = text_node.content.sub(ALERT_TOKEN, "")

      # the newline after the token leaves a leading <br> behind
      while (leading = paragraph.children.first) && blank?(leading)
        leading.remove
      end

      paragraph.remove if all_children_are_blank?(paragraph)
    end

    def alert_label_node(doc, alert_type)
      label = Nokogiri::XML::Node.new("p", doc)
      label["data-alert-label"] = alert_type
      label.content = I18n.t("services.html.parser.alerts.#{alert_type}")
      label
    end

    def img_of_size(source, width = 1500, quality: 81)
      Images::Optimizer.call(source, width: 1720, quality: 81).gsub(",", "%2C")
    end

    def all_children_are_blank?(node)
      node.children.all? { |child| blank?(child) }
    end

    def blank?(node)
      (node.text? && node.content.strip == "") || (node.element? && node.name == "br")
    end

    def allowed_image_host?(src)
      ImageUri.new(src).allowed?
    end

    def sanitized_caption_text(image)
      raw_text = image["data-lightbox-caption"].presence || image["alt"].presence
      return "" if raw_text.blank?

      sanitized = ActionController::Base.helpers.strip_tags(raw_text.to_s).squish
      return "" if sanitized.blank?
      return "" if default_caption?(sanitized)

      sanitized
    end

    def default_caption?(text)
      DEFAULT_IMAGE_CAPTIONS.any? { |value| value.casecmp?(text) }
    end

    def build_figure_for(link)
      return if link.nil?

      figure = Nokogiri::XML::Node.new("figure", link.document)
      parent = link.parent

      if parent&.name == "p"
        significant_children = parent.children.reject { |child| blank?(child) }

        if significant_children.one? && significant_children.first == link
          parent.replace(figure)
        else
          link.replace(figure)
        end
      else
        link.replace(figure)
      end

      figure.add_child(link)
      figure
    end

    def user_link_if_exists(mention)
      username = mention.delete("@").downcase
      if User.find_by(username: username)
        <<~HTML.chomp
          <a class='mentioned-user' href='#{ApplicationConfig['APP_PROTOCOL']}#{Settings::General.app_domain}/#{username}'>@#{username}</a>
        HTML
      else
        mention
      end
    end

    def possibly_raw_tag_syntax?(array)
      (RAW_TAG_DELIMITERS & array).any?
    end
  end
end
