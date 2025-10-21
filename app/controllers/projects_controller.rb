class ProjectsController < ApplicationController
  layout "application"

  def index
    directory = Organizations::Directory.new(params)
    paginated = directory.paginated

    respond_to do |format|
      format.html do
        @per_page = directory.per_page
        @initial_query = directory.search_term
        @sort = directory.sort
        @projects_payload = serialize_projects(paginated)
        @meta_payload = serialize_meta(paginated)
        set_surrogate_key_header "projects-index"
      end

      format.json do
        render json: {
          projects: serialize_projects(paginated),
          meta: serialize_meta(paginated)
        }
      end
    end
  end

  private

  def serialize_projects(collection)
    collection.map do |organization|
      {
        id: organization.id,
        name: organization.name,
        slug: organization.slug,
        summary: organization.summary,
        tag_line: organization.tag_line,
        profile_image: organization.profile_image_90,
        url: organization.url,
        reputation_score: organization.reputation_score,
        created_at: organization.created_at&.iso8601,
        articles_count: organization.articles_count
      }
    end
  end

  def serialize_meta(collection)
    {
      page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
