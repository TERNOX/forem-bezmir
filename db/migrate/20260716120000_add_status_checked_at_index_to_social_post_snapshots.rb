# Supports SocialEmbeds::RefreshSnapshotsWorker's scan, which filters out deleted
# rows and orders the rest by checked_at. Without this the scheduled batch would
# sort all non-deleted rows every run as the table grows.
class AddStatusCheckedAtIndexToSocialPostSnapshots < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :social_post_snapshots, %i[source_status checked_at],
              name: "index_social_post_snapshots_on_status_and_checked_at",
              algorithm: :concurrently
  end
end
