# Fork-only: creates (or refreshes) a catalog Game from an IGDB result and queues
# the download of its images to our storage.
module Games
  class ImportFromIgdb
    def self.call(...)
      new(...).call
    end

    # @param result [Igdb::Client::Result, Integer] a search result or an IGDB id
    def initialize(result, client: Igdb::Client.new)
      @result = result
      @client = client
    end

    # @return [Game]
    def call
      result = @result.is_a?(Igdb::Client::Result) ? @result : @client.find(@result)
      raise Igdb::Client::Error, "IGDB game not found" unless result

      game = Game.find_or_initialize_by(igdb_id: result.igdb_id)
      images_changed = game.igdb_cover_image_id != result.cover_image_id ||
        game.igdb_artwork_image_id != result.artwork_image_id
      game.assign_attributes(
        title: game.title.presence || result.title,
        igdb_url: result.url,
        release_year: result.release_year,
        platforms: result.platforms,
        igdb_cover_image_id: result.cover_image_id,
        igdb_artwork_image_id: result.artwork_image_id,
      )
      game.save!
      Games::FetchImagesWorker.perform_async(game.id) if images_changed || game.images_pending?
      game
    end
  end
end
