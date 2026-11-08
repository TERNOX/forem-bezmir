# Fork-only: re-hosts a catalog game's IGDB cover/artwork on our storage so the
# voting pages don't depend on the IGDB CDN. Admin-uploaded images are kept.
module Games
  class FetchImagesWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: 5, lock: :until_executed

    def perform(game_id)
      game = Game.find_by(id: game_id)
      return unless game

      if game.igdb_cover_image_id.present? && game.cover_image.blank?
        game.remote_cover_image_url = Game.igdb_image_url(game.igdb_cover_image_id, "t_cover_big_2x")
      end
      if game.igdb_artwork_image_id.present? && game.artwork_image.blank?
        game.remote_artwork_image_url = Game.igdb_image_url(game.igdb_artwork_image_id, "t_screenshot_huge")
      end
      game.save! if game.changed?
    end
  end
end
