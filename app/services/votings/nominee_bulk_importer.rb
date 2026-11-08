# Fork-only: turns a pasted list of game titles (one per line) into nominees.
# Each title is matched against the catalog first (case-insensitive exact title),
# then against IGDB (exact name match preferred, else the top result). Lines
# starting with "!" are added as custom (non-game) cards as-is.
module Votings
  class NomineeBulkImporter
    MAX_LINES = 60
    Report = Struct.new(:added, :not_found, :skipped, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(category:, text:, client: Igdb::Client.new)
      @category = category
      @lines = text.to_s.lines.map(&:strip).compact_blank.uniq.first(MAX_LINES)
      @client = client
    end

    def call
      report = Report.new(added: [], not_found: [], skipped: [])
      @lines.each do |line|
        if line.start_with?("!")
          add_custom(line.delete_prefix("!").strip, report)
          next
        end

        game = find_game(line)
        if game.nil?
          report.not_found << line
        elsif @category.nominees.exists?(game_id: game.id)
          report.skipped << game.title
        elsif @category.nominees.create(game: game).persisted?
          report.added << game.title
        else
          report.not_found << line
        end
      end
      report
    end

    private

    def find_game(title)
      Game.find_by_title_ci(title) || import_from_igdb(title)
    end

    def import_from_igdb(title)
      return unless Igdb::Client.configured?

      results = @client.search(title, limit: 10)
      match = results.detect { |r| normalize(r.title) == normalize(title) } || results.first
      match && Games::ImportFromIgdb.call(match, client: @client)
    rescue Igdb::Client::Error => e
      Rails.logger.warn("[Votings::NomineeBulkImporter] #{title}: #{e.message}")
      nil
    end

    def add_custom(title, report)
      return if title.blank?

      if @category.nominees.where(game_id: nil).where("lower(title) = ?", title.downcase).exists?
        report.skipped << title
      elsif @category.nominees.create(title: title).persisted?
        report.added << title
      end
    end

    def normalize(title)
      title.to_s.downcase.gsub(/[^\p{L}\p{N}]+/, "")
    end
  end
end
