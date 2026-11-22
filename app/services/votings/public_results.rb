# Fork-only: the results of a voting as the public page shows them
# (Votings::PagePayload's `results`):
#
#   { "ballotsCount" => 12,
#     "categories" => { "<category id>" => { "voters" => 10,
#       "rows" => [{ "nomineeId", "place", "points", "votes", "firsts", "share" }] } } }
#
# Always JSON-shaped (string keys, category ids as strings), exactly what
# Voting#results_snapshot holds after a round trip through jsonb, so a stored
# snapshot and a live count compare with a plain ==.
module Votings
  class PublicResults
    # @param results [Hash, nil] an existing Votings::Results.call(voting), to
    #   avoid tallying twice; counted afresh when nil.
    def self.call(voting, results: nil)
      new(results || Votings::Results.call(voting)).call
    end

    def initialize(results)
      @results = results
    end

    def call
      {
        "ballotsCount" => @results[:ballots_count],
        "categories" => @results[:categories].to_h do |category_result|
          [category_result.category.id.to_s, category_json(category_result)]
        end
      }
    end

    private

    def category_json(category_result)
      total = [category_result.max_points, 1].max
      rows = category_result.rows.map do |row|
        { "nomineeId" => row.nominee.id, "place" => row.place, "points" => row.points, "votes" => row.votes,
          "firsts" => row.firsts, "share" => (row.points * 100.0 / total).round(1) }
      end
      { "voters" => category_result.voters, "rows" => rows }
    end
  end
end
