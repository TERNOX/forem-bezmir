module Admin
  # Fork-only: manage community votings ("Гра року" and similar).
  class VotingsController < Admin::ApplicationController
    layout "admin"

    before_action :set_voting, except: %i[index new create]

    def index
      @votings = Voting.order(created_at: :desc)
      @ballot_counts = VotingBallot.where.not(submitted_at: nil).group(:voting_id).count
    end

    def show
      @categories = @voting.categories.includes(nominees: :game)
      @nominee_vote_counts = VotingChoice.joins(:category).where(voting_categories: { voting_id: @voting.id })
        .where.not(voting_nominee_id: nil).group(:voting_nominee_id).count
      @ballots_count = @voting.submitted_ballots.count
      @igdb_configured = Igdb::Client.configured?
    end

    def new
      @voting = Voting.new(opens_at: Time.current.beginning_of_day, closes_at: 2.weeks.from_now.end_of_day)
    end

    def edit; end

    def create
      @voting = Voting.new(voting_params)
      if @voting.save
        redirect_to admin_voting_path(@voting), notice: "Voting created. Now add nominations."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @voting.update(voting_params)
        redirect_to admin_voting_path(@voting), notice: "Voting updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @voting.destroy
      redirect_to admin_votings_path, notice: "Voting deleted."
    end

    # Always the live count; once published, also whether the public page's
    # snapshot still matches it.
    def results
      @results = Votings::Results.call(@voting)
      respond_to do |format|
        format.html do
          @other_answer_totals = other_answer_totals
          if @voting.results_snapshot
            @snapshot_matches = Votings::PublicResults.call(@voting, results: @results) == @voting.results_snapshot
          end
        end
        format.csv do
          send_data results_csv(@results), filename: "#{@voting.slug}-results-#{Date.current}.csv",
                                           type: "text/csv; charset=utf-8"
        end
      end
    end

    def publish_results
      @voting.publish_results!
      redirect_to results_admin_voting_path(@voting), notice: "Results are now public."
    end

    # Re-takes the published snapshot from the current count.
    def republish_results
      unless @voting.results_published?
        return redirect_to results_admin_voting_path(@voting), notice: "Results are not published."
      end

      @voting.publish_results!
      redirect_to results_admin_voting_path(@voting), notice: "Published results updated to the current count."
    end

    def unpublish_results
      @voting.unpublish_results!
      redirect_to results_admin_voting_path(@voting), notice: "Results are hidden again."
    end

    # Copies the voting with all nominations and nominees (no ballots), unpublished,
    # e.g. to start next year's "Гра року" from this year's structure.
    def clone
      copy = Votings::Cloner.call(@voting)
      redirect_to edit_admin_voting_path(copy), notice: "Voting copied. Adjust the title, slug and dates."
    end

    private

    def set_voting
      @voting = Voting.find(params[:id])
    end

    def voting_params
      params.require(:voting).permit(
        :title, :slug, :description_markdown, :banner_image, :remove_banner_image,
        :opens_at, :closes_at, :published, :top_level_path, :require_account_before_start, :min_user_score
      )
    end

    # { [category_id, normalised text] => count } over every ballot, counted or
    # not: merging an "other" answer into a nominee rewrites all of them.
    def other_answer_totals
      VotingChoice.joins(:category).where(voting_categories: { voting_id: @voting.id })
        .where(voting_nominee_id: nil).where.not(other_text: [nil, ""])
        .group(:voting_category_id, Arel.sql("lower(trim(voting_choices.other_text))")).count
    end

    def results_csv(results)
      require "csv"
      CSV.generate do |csv|
        csv << ["Category", "Place", "Nominee", "Points", "Votes", "First places"]
        results[:categories].each do |category_result|
          category_result.rows.each do |row|
            csv << [category_result.category.title, row.place, row.nominee.display_title, row.points, row.votes,
                    row.firsts]
          end
          category_result.other_answers.each do |text, count|
            csv << [category_result.category.title, nil, "Other: #{text}", nil, count, nil]
          end
        end
      end
    end
  end
end
