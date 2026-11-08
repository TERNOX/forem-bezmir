module Admin
  # Fork-only: the shared game catalog used by votings, plus the search endpoint
  # behind the nominee picker (catalog first, then IGDB).
  class GamesController < Admin::ApplicationController
    layout "admin"

    before_action :set_game, only: %i[edit update refresh]

    def index
      @games = Game.order(created_at: :desc)
      @games = @games.title_matching(params[:q]) if params[:q].present?
      @games = @games.page(params[:page]).per(60)
    end

    def edit; end

    def update
      if @game.update(game_params)
        redirect_to admin_games_path, notice: "Game updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Re-pulls title metadata and images from IGDB (keeps a custom title).
    def refresh
      if @game.igdb_id.blank?
        redirect_to edit_admin_game_path(@game), alert: "This game is not linked to IGDB."
        return
      end

      @game.remove_cover_image! if params[:reset_images] == "1"
      @game.remove_artwork_image! if params[:reset_images] == "1"
      @game.save!
      Games::ImportFromIgdb.call(@game.igdb_id)
      redirect_to edit_admin_game_path(@game), notice: "Refreshed from IGDB. Images re-download in the background."
    rescue Igdb::Client::Error => e
      redirect_to edit_admin_game_path(@game), alert: "IGDB: #{e.message}"
    end

    # GET /admin/content_manager/games/search?q=hades
    def search
      query = params[:q].to_s.strip
      local = query.present? ? Game.title_matching(query).order(release_year: :desc).limit(8) : Game.none
      payload = {
        local: local.map { |game| game_json(game) },
        igdb: [],
        igdb_configured: Igdb::Client.configured?
      }
      if query.length >= 2 && payload[:igdb_configured]
        known_ids = local.map(&:igdb_id).compact
        payload[:igdb] = Igdb::Client.new.search(query).reject { |r| known_ids.include?(r.igdb_id) }.map(&:as_json)
      end
      render json: payload
    rescue Igdb::Client::Error => e
      render json: payload.merge(error: e.message)
    end

    private

    def set_game
      @game = Game.find(params[:id])
    end

    def game_params
      params.require(:game).permit(:title, :release_year, :cover_image, :artwork_image,
                                   :remove_cover_image, :remove_artwork_image)
    end

    def game_json(game)
      { id: game.id, igdb_id: game.igdb_id, title: game.title, release_year: game.release_year,
        platforms: game.platforms, cover_url: game.cover_url }
    end
  end
end
