class CreateCoAuthorInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :co_author_invitations do |t|
      t.references :article, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :status, null: false, default: "pending"
      t.datetime :responded_at

      t.timestamps
    end
    # Indexes are added concurrently in 20261007120001_add_indexes_to_co_author_invitations.
  end
end
