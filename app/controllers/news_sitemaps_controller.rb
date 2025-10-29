class NewsSitemapsController < ApplicationController
  before_action :set_cache_headers

  def show
    @articles = Sitemaps::NewsArticlesQuery.new.call
    @publication_name = Settings::Community.community_name
    @publication_language = Settings::General.default_content_language.presence || I18n.locale.to_s

    respond_to do |format|
      format.xml { render :show, layout: false }
    end
  end

  private

  def set_cache_headers
    set_cache_control_headers(1.hour.to_i, stale_while_revalidate: 15.minutes.to_i, stale_if_error: 1.day.to_i)
  end
end
