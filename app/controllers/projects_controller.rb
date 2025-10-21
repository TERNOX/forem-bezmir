class ProjectsController < ApplicationController
  SORT_OPTIONS = {
    "reputation_desc" => { column: :reputation_score, direction: :desc },
    "reputation_asc" => { column: :reputation_score, direction: :asc },
    "created_at_desc" => { column: :created_at, direction: :desc },
    "created_at_asc" => { column: :created_at, direction: :asc },
  }.freeze

  helper_method :active_sort_option

  def index
    @query = params[:q].to_s.strip
    @sort = active_sort_option
    @sort_options = SORT_OPTIONS

    @organizations = Organization.all
    @organizations = @organizations.merge(Organization.search_organizations(@query)) if @query.present?
    @organizations = apply_sort(@organizations)
    @organizations = @organizations.page(params[:page]).per(24)
  end

  private

  def apply_sort(scope)
    sort_configuration = SORT_OPTIONS[@sort]
    direction = sort_configuration[:direction]
    column = sort_configuration[:column]

    secondary_order = column == :created_at ? { name: :asc } : { created_at: :desc }

    scope.order(column => direction).order(secondary_order)
  end

  def active_sort_option
    requested = params[:sort].to_s
    return requested if SORT_OPTIONS.key?(requested)

    "reputation_desc"
  end
end
