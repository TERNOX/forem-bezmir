module Admin
  # Fork-only: nominations inside a voting.
  class VotingCategoriesController < Admin::ApplicationController
    layout "admin"

    before_action :set_voting
    before_action :set_category, except: %i[new create]

    def new
      @category = @voting.categories.new
    end

    def edit; end

    def create
      @category = @voting.categories.new(category_params)
      if @category.save
        redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"), notice: "Nomination added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @category.update(category_params)
        redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"), notice: "Nomination updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy
      redirect_to admin_voting_path(@voting), notice: "Nomination deleted."
    end

    def move
      Votings::Reorderer.move(@category, siblings: @voting.categories, direction: params[:direction])
      redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}")
    end

    # Adds every nominee of another nomination (any voting) that isn't here yet.
    def copy_nominees
      source = VotingCategory.find(params[:source_category_id])
      added = Votings::NomineeCopier.call(from: source, to: @category)
      redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"),
                  notice: "Copied #{added} nominee(s) from “#{source.title}”."
    end

    # Counts one "other" answer (as grouped on the results page) as a nominee
    # of this nomination, on every ballot that gave it. Irreversible.
    def merge_other_answer
      results_path = results_admin_voting_path(@voting)
      text = params[:text].to_s
      nominee = @category.nominees.find_by(id: params[:nominee_id].to_s)
      return redirect_to(results_path, alert: "Pick a nominee of “#{@category.title}”.") unless nominee
      return redirect_to(results_path, alert: "Pick an “other” answer to count.") if text.strip.empty?

      result = Votings::OtherAnswerMerger.call(category: @category, text: text, nominee: nominee)
      if result.total.zero?
        return redirect_to(results_path, alert: "No “#{text}” answers found in “#{@category.title}”.")
      end

      Audit::Logger.log(:internal, current_user, {
                          "action" => params[:action],
                          "controller" => params[:controller],
                          "voting_id" => @voting.id,
                          "voting_category_id" => @category.id,
                          "other_text" => text,
                          "voting_nominee_id" => nominee.id,
                          "merged" => result.merged,
                          "dropped" => result.dropped
                        })
      redirect_to results_path, notice: merge_notice(result, text, nominee)
    end

    protected

    def authorization_resource
      Voting
    end

    private

    def set_voting
      @voting = Voting.find(params[:voting_id])
    end

    def set_category
      @category = @voting.categories.find(params[:id])
    end

    def merge_notice(result, text, nominee)
      notice = "Counted #{helpers.pluralize(result.total, 'answer')} “#{text}” as “#{nominee.display_title}”"
      notice += " (#{helpers.pluralize(result.dropped, 'duplicate')} dropped)" if result.dropped.positive?
      "#{notice}."
    end

    def category_params
      params.require(:voting_category).permit(
        :title, :description, :max_choices, :required, :ranked, :allow_other, :card_style, :rank_points_text
      )
    end
  end
end
