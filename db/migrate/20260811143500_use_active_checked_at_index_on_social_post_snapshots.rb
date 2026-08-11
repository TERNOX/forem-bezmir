# The refresh worker scans non-deleted rows ordered by checked_at. A composite
# (source_status, checked_at) index led by an inequality (source_status <> deleted)
# can't be read in checked_at order, so Postgres still sorts. A partial index on
# checked_at (excluding deleted rows) matches the scan directly. Codex P2.
#
# source_status enum: unknown:0, live:1, deleted:2, unavailable:3.
class UseActiveCheckedAtIndexOnSocialPostSnapshots < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :social_post_snapshots,
                 name: "index_social_post_snapshots_on_status_and_checked_at",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :social_post_snapshots, :checked_at,
              where: "source_status <> 2",
              name: "index_social_post_snapshots_on_checked_at_active",
              algorithm: :concurrently
  end

  def down
    remove_index :social_post_snapshots,
                 name: "index_social_post_snapshots_on_checked_at_active",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :social_post_snapshots, %i[source_status checked_at],
              name: "index_social_post_snapshots_on_status_and_checked_at",
              algorithm: :concurrently
  end
end
