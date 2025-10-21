class ProjectsController < ApplicationController
  SORT_OPTIONS = {
    "created_at-desc" => { created_at: :desc, name: :asc },
    "created_at-asc" => { created_at: :asc, name: :asc },
    "articles_count-desc" => { articles_count: :desc, created_at: :desc, name: :asc },
    "articles_count-asc" => { articles_count: :asc, created_at: :asc, name: :asc }
  }.freeze

  helper_method :projects_sort_options

  def index
    @query = params[:q].to_s.strip
    @selected_sort = permitted_sort(params[:sort])
    @organizations = load_organizations
    @count_labels = I18n.t("views.projects.results.count")
    @empty_message = I18n.t("views.projects.empty")
  end

  private

  def projects_sort_options
    SORT_OPTIONS.keys
  end

  def load_organizations
    scope = if @query.present?
              Organization.search_organizations(@query)
            else
              Organization.all
            end

    scope.reorder(SORT_OPTIONS[@selected_sort]).load
  end

  def permitted_sort(sort_param)
    return "created_at-desc" if sort_param.blank?

    SORT_OPTIONS.key?(sort_param) ? sort_param : "created_at-desc"
  end
end
