module SocialEmbeds
  # Turns a plain-text social post body into a small, safe HTML fragment for the
  # archive card: HTML-escaped, bare URLs linkified, newlines -> <br>.
  module TextFormatter
    URL_REGEXP = %r{https?://[^\s<]+}
    # trailing punctuation that shouldn't be swallowed into the link
    TRAILING = /[)\].,!?:;'"]+\z/

    module_function

    def call(text)
      return if text.blank?

      escaped = CGI.escapeHTML(text.to_s)
      linked = escaped.gsub(URL_REGEXP) do |match|
        trailing = match[TRAILING]
        url = trailing ? match[0...-trailing.length] : match
        %(<a href="#{url}" rel="nofollow noopener ugc" target="_blank">#{url}</a>#{trailing})
      end
      linked.gsub(/\r?\n/, "<br>\n")
    end
  end
end
