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

    def results
      @results = Votings::Results.call(@voting)
      respond_to do |format|
        format.html
        format.csv do
          send_data results_csv(@results), filename: "#{@voting.slug}-results-#{Date.current}.csv",
                                           type: "text/csv; charset=utf-8"
        end
      end
    end

    def publish_results
      @voting.update!(results_published_at: Time.current)
      redirect_to results_admin_voting_path(@voting), notice: "Results are now public."
    end

    def unpublish_results
      @voting.update!(results_published_at: nil)
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

    def results_csv(results)
      require "csv"
      CSV.generate do |csv|
        csv << ["Category", "Place", "Nominee", "Points", "Votes", "First places"]
        results[:categories].each do |category_result|
          category_result.rows.each_with_index do |row, index|
            csv << [category_result.category.title, index + 1, row.nominee.display_title, row.points, row.votes,
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
