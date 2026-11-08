module Admin
  # Fork-only: nominees inside a voting nomination. A nominee is either a catalog
  # game (picked by game_id, or imported on the fly by igdb_id) or a custom card.
  class VotingNomineesController < Admin::ApplicationController
    layout "admin"

    before_action :set_voting_and_category
    before_action :set_nominee, only: %i[edit update destroy move]

    def edit; end

    def create
      game = resolve_game
      @nominee = @category.nominees.new(nominee_params.merge(game: game))
      if @nominee.save
        respond_success("Added “#{@nominee.display_title}”.")
      else
        respond_failure(@nominee.errors.full_messages.to_sentence)
      end
    rescue Igdb::Client::Error => e
      respond_failure("IGDB: #{e.message}")
    end

    # One title per line; each line is matched against the catalog first, then IGDB.
    def bulk_create
      report = Votings::NomineeBulkImporter.call(category: @category, text: params[:titles].to_s)
      notice = "Added #{report.added.size} nominee(s)."
      notice += " Not found: #{report.not_found.join(', ')}." if report.not_found.any?
      notice += " Already there: #{report.skipped.join(', ')}." if report.skipped.any?
      redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"), notice: notice
    end

    def update
      if params[:replace_igdb_id].present? || params[:replace_game_id].present?
        @nominee.game = resolve_game(igdb_id: params[:replace_igdb_id], game_id: params[:replace_game_id])
      end
      if @nominee.update(nominee_params)
        redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"), notice: "Nominee updated."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue Igdb::Client::Error => e
      redirect_to edit_admin_voting_voting_category_voting_nominee_path(@voting, @category, @nominee),
                  alert: "IGDB: #{e.message}"
    end

    def destroy
      @nominee.destroy
      redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"), notice: "Nominee removed."
    end

    def move
      Votings::Reorderer.move(@nominee, siblings: @category.nominees, direction: params[:direction])
      redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}")
    end

    protected

    def authorization_resource
      Voting
    end

    private

    def set_voting_and_category
      @voting = Voting.find(params[:voting_id])
      @category = @voting.categories.find(params[:voting_category_id])
    end

    def set_nominee
      @nominee = @category.nominees.find(params[:id])
    end

    def nominee_params
      params.fetch(:voting_nominee, {}).permit(:title, :subtitle, :link_url, :image, :remove_image)
    end

    def resolve_game(igdb_id: params[:igdb_id], game_id: params[:game_id])
      return Game.find(game_id) if game_id.present?
      return Games::ImportFromIgdb.call(igdb_id.to_i) if igdb_id.present?

      nil
    end

    def respond_success(message)
      respond_to do |format|
        format.html do
          redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"), notice: message
        end
        format.json { render json: { message: message }, status: :created }
      end
    end

    def respond_failure(message)
      respond_to do |format|
        format.html do
          redirect_to admin_voting_path(@voting, anchor: "category-#{@category.id}"), alert: message
        end
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
    end
  end
end
