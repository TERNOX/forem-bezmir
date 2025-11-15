module MarkdownProcessor
  module Fixer
    class FixForComment < Base
      METHODS = %i[
        underscores_in_usernames
        replace_spoiler_delimiters
      ].freeze
    end
  end
end
