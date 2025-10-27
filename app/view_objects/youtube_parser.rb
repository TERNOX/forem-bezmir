class YoutubeParser

  def initialize(url)
    @url = url.to_s.strip
  end

  def call
    return nil if url.blank? || !youtube_url?

    youtube_embed_url
  end

  private

  attr_reader :url

  def youtube_url?
    YoutubeUrl.youtube_url?(url) && video_id.present?
  end

  def youtube_embed_url
    YoutubeUrl.embed_url(video_id, start_time: YoutubeUrl.extract_start_time(url))
  end

  def video_id
    @video_id ||= YoutubeUrl.extract_video_id(url)
  end
end
