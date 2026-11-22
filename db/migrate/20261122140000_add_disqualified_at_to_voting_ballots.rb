# Fork-only: an admin can disqualify a single ballot (suspected ballot stuffing)
# without suspending the member. A disqualified ballot is not counted
# (Votings::Results) but stays editable by its voter. nil = not disqualified.
class AddDisqualifiedAtToVotingBallots < ActiveRecord::Migration[8.0]
  def up
    add_column :voting_ballots, :disqualified_at, :datetime
  end

  def down
    # Dropping the column this migration added is the whole rollback.
    safety_assured { remove_column :voting_ballots, :disqualified_at }
  end
end
