# Fork-only: copies the nominees of one nomination into another, skipping games
# (and custom cards with the same title) that are already there.
module Votings
  class NomineeCopier
    # @return [Integer] how many nominees were added
    def self.call(from:, to:)
      existing_game_ids = to.nominees.where.not(game_id: nil).pluck(:game_id)
      existing_titles = to.nominees.where(game_id: nil).pluck(:title).map { |t| t.to_s.downcase }
      added = 0
      from.nominees.each do |nominee|
        next if nominee.game_id && existing_game_ids.include?(nominee.game_id)
        next if nominee.game_id.nil? && existing_titles.include?(nominee.title.to_s.downcase)

        copy = to.nominees.new(game_id: nominee.game_id, title: nominee.title, subtitle: nominee.subtitle,
                               link_url: nominee.link_url)
        copy_image(nominee, copy)
        added += 1 if copy.save
      end
      added
    end

    def self.copy_image(nominee, copy)
      Cloner.copy_upload(nominee.image, copy, :image)
    end
  end
end
