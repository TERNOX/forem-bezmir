module Html
  class Parser
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
    SPOILER_START_COMMENT = "spoiler".freeze
    SPOILER_END_COMMENT = "endspoiler".freeze
    SPOILER_START_LITERAL = "<!--#{SPOILER_START_COMMENT}-->".freeze
    SPOILER_END_LITERAL = "<!--#{SPOILER_END_COMMENT}-->".freeze
    SPOILER_VISUAL_LABEL = "Spoiler".freeze
    SPOILER_ARIA_LABEL = "Spoiler content. Focus to reveal.".freeze

    attr_accessor :html
    private :html=

    def initialize(html)
      @html = html
    end

    def remove_nested_linebreak_in_list
      html_doc = Nokogiri::HTML(@html)
      html_doc.xpath("//*[self::ul or self::ol or self::li]/br").each(&:remove)
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

      doc.css("img").each do |img|
        src = img.attr("src")
        next unless src
        # allow image to render as-is
        next if allowed_image_host?(src)

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

      @html = doc.to_html

      self
    end

    def wrap_all_images_in_links
      doc = Nokogiri::HTML.fragment(@html)

      doc.search("p img").each do |image|
        next if image.parent.name == "a"

        image.swap("<a href='#{image.attr('src')}' class='article-body-image-wrapper'>#{image}</a>")
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
      doc = Nokogiri::HTML.fragment(@html)

      doc.search("div.highlight").each do |codeblock|
        codeblock.add_class("js-code-highlight")
      end

      @html = doc.to_html

      self
    end

    def add_control_panel_to_codeblock
      doc = Nokogiri::HTML.fragment(@html)

      doc.search("div.highlight").each do |codeblock|
        codeblock.add_child('<div class="highlight__panel js-actions-panel"></div>')
      end

      @html = doc.to_html

      self
    end

    def add_fullscreen_button_to_panel
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
      doc = Nokogiri::HTML.fragment(@html)
      doc.search("table").each { |table| table.swap("<div class='table-wrapper-paragraph'>#{table}</div>") }
      @html = doc.to_html

      self
    end

    def remove_empty_paragraphs
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

      @html =
        if html_doc.at_css("body")
          html_doc.at_css("body").inner_html
        else
          html_doc.to_html
        end

      self
    end

    def wrap_all_figures_with_tags
      html_doc = Nokogiri::HTML(@html)

      html_doc.xpath("//figcaption").each do |caption|
        next if caption.parent.name == "figure"
        next unless caption.previous_element

        fig = html_doc.create_element "figure"
        prev = caption.previous_element
        prev.replace(fig) << prev << caption
      end

      @html =
        if html_doc.at_css("body")
          html_doc.at_css("body").inner_html
        else
          html_doc.to_html
        end

      self
    end

    def wrap_spoilers
      fragment = Nokogiri::HTML.fragment(@html)
      wrap_spoiler_comments(fragment)
      @html = fragment.to_html

      self
    end

    def wrap_mentions_with_links
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

      @html =
        if html_doc.at_css("body")
          html_doc.at_css("body").inner_html
        else
          html_doc.to_html
        end

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

    def wrap_spoiler_comments(node)
      return unless node

      child = node.children.first

      while child
        if child.text? && text_contains_spoiler_marker?(child.text)
          replacement = split_text_node_by_spoiler_marker(child, parent: node)
          child = replacement || child.next
          next
        end

        next_child = child.next

        if spoiler_marker_type(child) == :start
          start_marker = child
          sibling = start_marker.next
          nodes_to_wrap = []
          closing_comment = nil

          while sibling
            next_sibling = sibling.next

            if spoiler_marker_type(sibling) == :end
              closing_comment = sibling
              break
            else
              nodes_to_wrap << sibling
            end

            sibling = next_sibling
          end

          if closing_comment
            span = node.document.create_element("span")
            span["data-spoiler"] = "true"
            span["data-spoiler-label"] = SPOILER_VISUAL_LABEL
            span["tabindex"] = "0"
            span["aria-label"] = SPOILER_ARIA_LABEL

            insertion_point = nodes_to_wrap.first || closing_comment

            if insertion_point.parent
              insertion_point.add_previous_sibling(span)
            else
              node.add_child(span)
            end
            nodes_to_wrap.each { |wrap_node| span.add_child(wrap_node) }

            start_marker.remove
            closing_comment.remove

            wrap_spoiler_comments(span)
            next_child = span.next
          else
            next_child = start_marker.next
          end
        elsif child.element? && !%w[code pre].include?(child.name)
          wrap_spoiler_comments(child)
        end

        child = next_child
      end
    end

    def spoiler_marker_type(node)
      return unless node

      if node.comment?
        text = node.text.to_s.strip
        return :start if text == SPOILER_START_COMMENT
        return :end if text == SPOILER_END_COMMENT
      elsif node.text?
        text = node.text.to_s.strip
        return :start if text == SPOILER_START_LITERAL
        return :end if text == SPOILER_END_LITERAL
      end
    end

    def text_contains_spoiler_marker?(text)
      text.include?(SPOILER_START_LITERAL) || text.include?(SPOILER_END_LITERAL)
    end

    def split_text_node_by_spoiler_marker(text_node, parent: nil)
      content = text_node.text.to_s
      return unless text_contains_spoiler_marker?(content)

      nodes_to_insert = []

      parent ||= text_node.parent
      return unless parent

      while content.present?
        start_index = content.index(SPOILER_START_LITERAL)
        end_index = content.index(SPOILER_END_LITERAL)
        marker_type, marker_index = next_marker_from(start_index, end_index)

        if marker_index.nil?
          nodes_to_insert << text_node.document.create_text_node(content)
          break
        end

        if marker_index.positive?
          nodes_to_insert << text_node.document.create_text_node(content[0...marker_index])
        end

        marker_comment = text_node.document.create_comment(marker_type == :start ? SPOILER_START_COMMENT : SPOILER_END_COMMENT)
        nodes_to_insert << marker_comment

        marker_length = marker_type == :start ? SPOILER_START_LITERAL.length : SPOILER_END_LITERAL.length
        content = content[(marker_index + marker_length)..]
      end

      nodes_to_insert.reject! { |n| n.text? && n.text.empty? }

      nodes_to_insert.each { |new_node| text_node.add_previous_sibling(new_node) }
      text_node.remove

      nodes_to_insert.first
    end

    def next_marker_from(start_index, end_index)
      if start_index && (!end_index || start_index < end_index)
        [:start, start_index]
      elsif end_index
        [:end, end_index]
      end
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
