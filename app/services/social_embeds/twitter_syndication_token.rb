module SocialEmbeds
  # Computes the opaque `token` the Twitter/X syndication endpoint
  # (cdn.syndication.twimg.com/tweet-result) expects for a given tweet id.
  #
  # Mirrors the widely-used react-tweet algorithm:
  #   ((Number(id) / 1e15) * Math.PI).toString(36).replace(/(0+|\.)/g, '')
  #
  # Ruby Float is IEEE-754 double just like JS Number, so the arithmetic matches;
  # we replicate JS Number#toString(36) for the fractional part. This is a
  # best-effort, unofficial path used only to fetch photos — callers must fall
  # back gracefully (e.g. to oEmbed) if syndication rejects the token.
  module TwitterSyndicationToken
    DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz".freeze
    FRACTIONAL_DIGITS = 24

    module_function

    def call(id)
      value = (id.to_f / 1e15) * Math::PI
      to_base36(value).gsub(/(0+|\.)/, "")
    end

    def to_base36(value)
      return "0" if value.zero?

      int_part = value.floor
      frac = value - int_part
      result = int_part.to_s(36).dup
      result << "."
      FRACTIONAL_DIGITS.times do
        break if frac <= 0

        frac *= 36
        digit = frac.floor
        result << DIGITS[digit]
        frac -= digit
      end
      result
    end
  end
end
