require "nokogiri"

module YoutubeUrl
  EMBED_DOMAIN = "youtube-nocookie.com".freeze
  EMBED_HOST = "www.#{EMBED_DOMAIN}".freeze
  EMBED_URL_PREFIX = "https://#{EMBED_HOST}/embed/".freeze
  EMBED_HOSTS = [EMBED_DOMAIN, "youtube.com"].freeze
  VIDEO_HOSTS = (EMBED_HOSTS + ["youtu.be"]).freeze
  TIME_MARKER_TO_SECONDS = { "h" => 3600, "m" => 60, "s" => 1 }.freeze

  module_function

  def embed_url(video_id, start_time: nil)
    return if video_id.blank?

    query = start_time.present? ? "?start=#{start_time}" : ""
    "#{EMBED_URL_PREFIX}#{video_id}#{query}"
  end

  def embed_url?(url)
    host_matches?(url, EMBED_HOSTS)
  end

  def youtube_url?(url)
    host_matches?(url, VIDEO_HOSTS)
  end

  def extract_video_id(url)
    uri = build_uri(url)
    return unless uri

    host = normalized_host(uri)
    case host
    when "youtu.be"
      uri.path.split("/").last
    when "youtube.com", EMBED_DOMAIN
      params = Rack::Utils.parse_query(uri.query.to_s)
      return params["v"] if params["v"].present?

      segments = uri.path.split("/")
      idx = segments.index("embed") || segments.index("v")
      segments[idx + 1] if idx
    end
  end

  def normalize_embed_src(url)
    return url if url.blank?
    return url unless youtube_url?(url)

    video_id = extract_video_id(url)
    return url if video_id.blank?

    embed_url(video_id, start_time: extract_start_time(url)) || url
  end

  def normalize_embed_html(html)
    return html if html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    fragment.css("iframe[src]").each do |iframe|
      normalized_src = normalize_embed_src(iframe["src"])
      iframe["src"] = normalized_src if normalized_src
    end
    fragment.to_html
  rescue StandardError
    html
  end

  def extract_start_time(url)
    time_parameter = find_time_parameter(url)
    convert_time_parameter(time_parameter) if time_parameter.present?
  end

  def find_time_parameter(url)
    return if url.blank?

    uri = build_uri(url)
    params = Rack::Utils.parse_query(uri&.query.to_s)
    params["start"].presence || params["t"].presence || extract_from_fragment(uri&.fragment)
  end

  def convert_time_parameter(param)
    return if param.blank?
    return param.to_i if param.match?(/^\d+$/)

    matches = param.scan(/(\d+)([hms])/i)
    return if matches.empty?

    matches.sum { |amount, marker| amount.to_i * TIME_MARKER_TO_SECONDS[marker.downcase] }
  end

  def host_matches?(url, hosts)
    host = host_from(url)
    hosts.include?(host)
  end

  def host_from(url)
    uri = build_uri(url)
    normalized_host(uri)
  end

  def normalized_host(uri)
    uri&.host&.downcase&.sub(/^www\./, "")
  end

  def build_uri(url)
    return if url.blank?

    uri = URI.parse(url)
    if uri.host.blank? && url.start_with?("//")
      uri = URI.parse("https:#{url}")
    end
    uri
  rescue URI::InvalidURIError
    nil
  end

  def extract_from_fragment(fragment)
    return if fragment.blank?

    match = fragment.match(/(?:start|t)=([0-9hms]+)/i)
    match[1] if match
  end

  private_class_method :convert_time_parameter, :normalized_host, :build_uri, :extract_from_fragment
end
