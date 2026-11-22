# Fork-only: everything the voting page's Preact app needs that is the same for
# every visitor (no current_user data, so the page stays cache-safe). The user's
# own ballot and eligibility come from VotingBallotsController#show.
module Votings
  class PagePayload
    include Rails.application.routes.url_helpers

    def self.call(...)
      new(...).call
    end

    def initialize(voting, now: Time.current)
      @voting = voting
      @now = now
    end

    def call
      categories = @voting.categories.includes(nominees: :game).to_a
      {
        voting: voting_json,
        categories: categories.map { |category| category_json(category) },
        # The snapshot taken on publishing, not a live count (see Voting#publish_results!).
        results: @voting.public_results,
        strings: I18n.t("views.votings.app"),
        signInUrl: "/enter"
      }
    end

    private

    def voting_json
      {
        id: @voting.id,
        slug: @voting.slug,
        title: @voting.title,
        status: @voting.status(@now),
        opensAt: @voting.opens_at&.iso8601,
        closesAt: @voting.closes_at&.iso8601,
        opensAtText: format_time(@voting.opens_at),
        closesAtText: format_time(@voting.closes_at),
        resultsPublished: @voting.results_published?,
        ballotUrl: voting_ballot_path(@voting.slug)
      }
    end

    def category_json(category)
      {
        id: category.id,
        title: category.title,
        description: category.description,
        maxChoices: category.max_choices,
        ranked: category.ranked?,
        required: category.required?,
        allowOther: category.allow_other?,
        cardStyle: category.card_style,
        points: category.rank_points_list,
        nominees: category.nominees.map { |nominee| nominee_json(nominee, category) }
      }
    end

    def nominee_json(nominee, category)
      {
        id: nominee.id,
        title: nominee.display_title,
        subtitle: nominee.subtitle.presence || nominee.game&.release_year&.to_s,
        imageUrl: nominee.image_url_for(category.card_style),
        linkUrl: nominee.link_url.presence
      }
    end

    def format_time(time)
      return unless time

      # uk only ships genitive month names ("грудня") as month_names_with_day;
      # %B would fall back to English there.
      month = Array(I18n.t("date.month_names_with_day", default: nil))[time.month] ||
        Array(I18n.t("date.month_names", default: nil))[time.month]
      format = I18n.t("views.votings.show.time_format")
      format = format.gsub("%B", month) if month.present?
      I18n.l(time, format: format)
    end
  end
end
