class ArticleWithVideoCreationService
  def initialize(article_params, current_user)
    @article_params = article_params
    @current_user = current_user
  end

  def create!
    Article.create! do |article|
      article = initial_article_with_params(article)
      article.processed_html = ""
      article.user_id = @current_user.id
      article.show_comments = true

      if @article_params[:video].present?
        article.video = @article_params[:video]
        article.video_state = "PROGRESSING"

        video_code = Video::UploadConfiguration.video_code_for(article.video)
        article.video_code = video_code
        article.video_source_url = Video::UploadConfiguration.stream_url_for(video_code)
        article.video_thumbnail_url = Video::UploadConfiguration.thumbnail_url_for(video_code)
      end
    end
  end

  def initial_article_with_params(article)
    if @current_user.setting.editor_version == "v1"
      title = I18n.t("services.article_with_video_creation_service.unpublished_video",
                     rand: rand(100_000).to_s(26))
      article.body_markdown = "---\ntitle: #{title}\npublished: false\ndescription: \ntags: \n---\n\n"
    else
      article.body_markdown = ""
      article.title = I18n.t("services.article_with_video_creation_service.unpublished_video",
                             rand: rand(100_000).to_s(26))
      article.published = false
    end
    article
  end
end
