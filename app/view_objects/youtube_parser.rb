class YoutubeParser

  YOUTUBE_HOST_REGEX = /\A(?:youtu\.be|(?:www\.)?youtube\.com)\z/i

  def initialize(url)
    @url = url.to_s.strip
  end

  def call
    return if url.blank?

    id = video_id
    return unless id

    youtube_embed_url(id)
  end

  def video_id
    return @video_id if defined?(@video_id)

    youtube_url?
    @video_id
  end

  def thumbnail_url
    id = video_id
    return unless id

    "https://img.youtube.com/vi/#{id}/hqdefault.jpg"
  end

  private

  attr_reader :url

  def youtube_url?
    return @youtube_url if defined?(@youtube_url)

    uri = parse_uri
    return @youtube_url = false unless uri&.host

    host = uri.host.downcase.sub(/\Awww\./, "")
    return @youtube_url = false unless host.match?(YOUTUBE_HOST_REGEX)

    @video_id = extract_video_id
    @youtube_url = @video_id.present?
  end

  def youtube_embed_url(id)
    "https://www.youtube.com/embed/#{id}"
  end

  def extract_video_id
    uri = parse_uri
    return unless uri

    host = uri.host.downcase.sub(/\Awww\./, "")

    if host == "youtu.be"
      # youtu.be/<id>
      uri.path.split("/").last
    elsif host.end_with?("youtube.com")
      # look for ?v= or /v/ or /embed/
      params = Rack::Utils.parse_query(uri.query.to_s)
      return params["v"] if params["v"].present?

      # paths like /embed/<id> or /v/<id>
      segments = uri.path.split("/")
      idx = segments.index("embed") || segments.index("v")
      segments[idx + 1] if idx
    end
  rescue URI::InvalidURIError
    nil
  end

  def parse_uri
    @parse_uri ||= URI.parse(url)
  rescue URI::InvalidURIError
    nil
  end
end
