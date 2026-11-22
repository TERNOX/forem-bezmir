# Fork-only: the public results of a voting are frozen when an admin publishes
# them (Voting#publish_results!), so later account deletions, suspensions,
# score changes or ballots cast while the voting is still open don't move the
# announced numbers. nil = not published, or published before this column.
class AddResultsSnapshotToVotings < ActiveRecord::Migration[8.0]
  def up
    add_column :votings, :results_snapshot, :jsonb
  end

  def down
    # Dropping the column this migration added is the whole rollback.
    safety_assured { remove_column :votings, :results_snapshot }
  end
end
