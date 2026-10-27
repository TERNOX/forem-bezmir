module SocialImageHelper
  def article_social_image_url(article, **options)
    Articles::SocialImage.new(article, **options).url
  end

  def user_social_image_url(user, width: 1200, height: 627)
    # Profile cards are part of the quote-card design; with it switched off, profiles keep the site image.
    if !Settings::General.quote_card_social_images || user&.social_image.blank?
      return Settings::General.main_social_image.to_s
    end

    Images::Optimizer.call(user.social_image, width: width, height: height, crop: "crop")
  end
end
