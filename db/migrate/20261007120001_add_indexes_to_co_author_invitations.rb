class AddIndexesToCoAuthorInvitations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Leading article_id also serves the per-article lookups, so no separate article_id index.
    add_index :co_author_invitations, %i[article_id user_id], unique: true,
                                                             algorithm: :concurrently, if_not_exists: true
    add_index :co_author_invitations, :user_id, algorithm: :concurrently, if_not_exists: true
  end
end
