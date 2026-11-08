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

    def category_params
      params.require(:voting_category).permit(
        :title, :description, :max_choices, :required, :ranked, :allow_other, :card_style
      )
    end
  end
end
