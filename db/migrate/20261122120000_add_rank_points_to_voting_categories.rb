# Fork-only: configurable points per place for ranked voting nominations
# (VotingCategory#rank_points; [] = the linear max_choices..1 scale).
#
# Also switches existing three-place ranked nominations to 5-3-1, but only in
# votings nobody has submitted a ballot for yet: the rules of a voting people
# already voted in never change. voting_categories is tiny, so the backfill
# runs in the same migration.
class AddRankPointsToVotingCategories < ActiveRecord::Migration[8.0]
  def up
    add_column :voting_categories, :rank_points, :integer, array: true, default: [], null: false

    safety_assured do
      execute <<~SQL.squish
        UPDATE voting_categories
        SET rank_points = '{5,3,1}'
        WHERE ranked = true
          AND max_choices = 3
          AND NOT EXISTS (
            SELECT 1 FROM voting_ballots
            WHERE voting_ballots.voting_id = voting_categories.voting_id
              AND voting_ballots.submitted_at IS NOT NULL
          )
      SQL
    end
  end

  def down
    # Dropping the column this migration added is the whole rollback.
    safety_assured { remove_column :voting_categories, :rank_points }
  end
end
