module MarkdownProcessor
  module Fixer
    class FixAll < Base
      METHODS = %i[
        add_quotes_to_title
        add_quotes_to_description
        lowercase_published
        convert_new_lines
        split_tags
        underscores_in_usernames
        replace_spoiler_delimiters
      ].freeze
    end
  end
end
