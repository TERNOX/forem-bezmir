module Api
  module V1
    # @note This controller partially authorizes with the ArticlePolicy, in an ideal world, it would
    #       fully authorize.  However, that refactor would require significantly more work.
    class ArticlesController < ApiController
      include Api::ArticlesController

      before_action :authenticate_with_api_key_or_write_token!, only: %i[create update]
      before_action :authenticate_with_api_key!, only: %i[me unpublish preview]
      before_action :validate_article_param_is_hash, only: %i[create update]
      before_action :set_cache_control_headers, only: %i[index show show_by_slug]
      after_action :verify_authorized, only: %i[create preview]

      protected

      # A private Forem runs this guard before the callbacks above
      # (ApplicationController#verify_private_forem); let a write_articles
      # token through it for the two actions it is meant for.
      def authenticate!
        return authenticate_with_api_key_or_write_token! if action_name.in?(%w[create update])

        super
      end

      private

      # The consent screen promises access to the member's own articles, but
      # ArticlePolicy#update? also lets admins and org admins edit others'. A
      # write_articles token must not carry those powers to a third-party
      # site, so with one only the member's own articles are updatable.
      def find_updatable_article
        article = super
        raise ActiveRecord::RecordNotFound if @oauth_write_token && article.user_id != @user.id

        article
      end
    end
  end
end
