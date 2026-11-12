class AddIndexesToSocialAutopost < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :settings_social_autoposts, %i[var subforem_id],
              unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :settings_social_autoposts, :subforem_id, algorithm: :concurrently, if_not_exists: true

    add_index :social_autopost_items, :article_id, unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :social_autopost_items, %i[status priority], algorithm: :concurrently, if_not_exists: true
    add_index :social_autopost_items, :posted_at, algorithm: :concurrently, if_not_exists: true
  end
end
