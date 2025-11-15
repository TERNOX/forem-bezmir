module MarkdownProcessor
  module Fixer
    # Services here in the Fixer module should inherit from this base class.
    # #call is implemented here so other services only need to define a
    # METHODS constant that is an Array of symbols referencing other methods
    # found here.
    #
    # For example
    # METHODS = %i[add_quotes_to_tile add_quotes_to_description]
    class Base
      FRONT_MATTER_DETECTOR = /-{3}.*?-{3}/m

      # Match @_username_ that is not preceded by backtick
      USERNAME_WITH_UNDERSCORE_REGEXP = /(?<!`)@_\w+_/

      SPOILER_DELIMITER = "!!".freeze
      SPOILER_START_MARKER = "<!--spoiler-->".freeze
      SPOILER_END_MARKER = "<!--endspoiler-->".freeze

      def self.call(markdown)
        return unless markdown

        fix_methods.reduce(markdown) { |acc, elem| public_send(elem, acc) }
      end

      def self.fix_methods
        self::METHODS
      end

      def self.add_quotes_to_title(markdown)
        add_quotes_to_section(markdown, section: "title")
      end

      def self.add_quotes_to_description(markdown)
        add_quotes_to_section(markdown, section: "description")
      end

      def self.lowercase_published(markdown)
        markdown.gsub(/-{3}.*?-{3}/m) do |front_matter|
          front_matter.gsub(/^published: /i, "published: ")
        end
      end

      def self.convert_new_lines(markdown)
        markdown.gsub("\r\n", "\n")
      end

      def self.split_tags(markdown)
        markdown.gsub(/\ntags:.*\n/) do |tags|
          tags.split(" #").join(",").delete("#").gsub(":,", ": ")
        end
      end

      def self.replace_spoiler_delimiters(markdown)
        return markdown unless markdown&.include?(SPOILER_DELIMITER)

        traverser = MarkdownProcessor::Traverser.new(markdown)
        replacements = []
        open_marker = false
        result = +""

        traverser.each do |line|
          if traverser.in_codeblock?
            result << line
            next
          end

          processed_line = +""
          index = 0
          inline_code_ranges = inline_code_ranges_for(line)

          while (match_index = line.index(SPOILER_DELIMITER, index))
            if inside_inline_code?(match_index, inline_code_ranges)
              processed_line << line[index...(match_index + SPOILER_DELIMITER.length)]
              index = match_index + SPOILER_DELIMITER.length
              next
            end

            processed_line << line[index...match_index]

            if open_marker
              processed_line << SPOILER_END_MARKER
              replacements << {
                type: :close,
                position: result.length + processed_line.length - SPOILER_END_MARKER.length,
              }
            else
              processed_line << SPOILER_START_MARKER
              replacements << {
                type: :open,
                position: result.length + processed_line.length - SPOILER_START_MARKER.length,
              }
            end

            open_marker = !open_marker
            index = match_index + SPOILER_DELIMITER.length
          end

          processed_line << line[index..] if index < line.length
          result << processed_line
        end

        if open_marker
          last_open = replacements.reverse.find { |entry| entry[:type] == :open }
          if last_open
            result[last_open[:position], SPOILER_START_MARKER.length] = SPOILER_DELIMITER
          end
        end

        replacements.empty? ? markdown : result
      end

      def self.inline_code_ranges_for(line)
        ranges = []
        index = 0

        while index < line.length
          break unless (backtick_index = line.index('`', index))

          backtick_run = 1
          while line[backtick_index + backtick_run] == '`'
            backtick_run += 1
          end

          closing_index = line.index('`' * backtick_run, backtick_index + backtick_run)

          unless closing_index
            index = backtick_index + backtick_run
            next
          end

          ranges << (backtick_index...(closing_index + backtick_run))
          index = closing_index + backtick_run
        end

        ranges
      end

      def self.inside_inline_code?(position, ranges)
        ranges.any? { |range| range.cover?(position) }
      end

      private_class_method :inline_code_ranges_for, :inside_inline_code?

      def self.underscores_in_usernames(markdown)
        return markdown unless markdown.match?(USERNAME_WITH_UNDERSCORE_REGEXP)

        traverser = MarkdownProcessor::Traverser.new(markdown)
        traverser.each do |line|
          next if traverser.in_codeblock?

          escape_underscored_username_in_line!(line)
        end.join
      end

      # Escapes underscored username that is not in code
      def self.escape_underscored_username_in_line!(line)
        line.scan(USERNAME_WITH_UNDERSCORE_REGEXP).each do |to_escape|
          line.sub!(to_escape, to_escape.gsub("_", "\\_"))
        end
        line
      end

      def self.add_quotes_to_section(markdown, section:)
        # Only add quotes to front matter, or text between triple dashes
        markdown.sub(FRONT_MATTER_DETECTOR) do |front_matter|
          front_matter.gsub(/#{section}: ?(?<content>.*?)(\r\n|\n)/m) do |target|
            # `content` is the captured group (.*?)
            captured_text = Regexp.last_match("content")
            # The query below checks if the whole text is wrapped in
            # either single or double quotes.
            match = captured_text.scan(/(^".*"$|^'.*'$)/)
            if match.empty?
              # Double quotes that aren't already escaped will get escaped.
              # Then the whole text get warped in double quotes.
              parsed_text = captured_text.gsub(/(?<!\\)"/, "\\\"")
              "#{section}: \"#{parsed_text}\"\n"
            else
              # if the text comes pre-warped in either single or double quotes,
              # no more processing is done
              target
            end
          end
        end
      end
    end
  end
end
