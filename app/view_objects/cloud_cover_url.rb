class CloudCoverUrl
  include ActionView::Helpers::AssetUrlHelper

  def initialize(url)
    @url = url
  end

  def call
    return if url.blank?
    return url if Rails.env.development?

    width = 1000
    img_src = url_without_prefix_nesting(url, width)

    Images::Optimizer.call(img_src, width: width, height: 1080, crop: "limit", quality: "auto", flags: "progressive", fetch_format: "auto")
  end

  private

  def url_without_prefix_nesting(url, width)
    return url if url.blank?
    return url unless url.start_with?("https://res.cloudinary.com/") && url.include?("w_#{width}/https://")

    url.split("w_#{width}/").last
  end

  attr_reader :url
end
