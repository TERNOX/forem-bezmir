module Organizations
  class Directory
    DEFAULT_PER_PAGE = 24
    PER_PAGE_MAX = 60
    DEFAULT_SORT = "reputation_desc".freeze
    SORT_OPTIONS = {
      "reputation_desc" => { reputation_score: :desc, created_at: :desc },
      "reputation_asc" => { reputation_score: :asc, created_at: :desc },
      "newest" => { created_at: :desc },
      "oldest" => { created_at: :asc }
    }.freeze

    attr_reader :params

    def initialize(params = {})
      @params = params
    end

    def paginated
      scoped.page(page).per(per_page)
    end

    def scoped
      @scoped ||= begin
        scope = Organization.all
        scope = apply_search(scope)
        apply_sort(scope)
      end
    end

    def search_term
      params[:q].to_s.strip
    end

    def sort
      params[:sort].to_s.tap do |value|
        return DEFAULT_SORT unless SORT_OPTIONS.key?(value)
        return value
      end
      DEFAULT_SORT
    end

    def per_page
      raw = params[:per_page].to_i
      return DEFAULT_PER_PAGE if raw <= 0

      [raw, PER_PAGE_MAX].min
    end

    def page
      params[:page].presence || 1
    end

    private

    def apply_search(scope)
      return scope if search_term.blank?

      Organization.search_organizations(search_term)
    end

    def apply_sort(scope)
      order = SORT_OPTIONS.fetch(sort, SORT_OPTIONS[DEFAULT_SORT])
      scope.reorder(order).order(name: :asc)
    end
  end
end
