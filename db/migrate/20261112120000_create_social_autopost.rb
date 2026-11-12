# Fork-only feature: automatic posting of community articles to a Telegram
# channel on a schedule. Indexes live in 20261112120100_add_indexes_to_social_autopost
# (added concurrently).
class CreateSocialAutopost < ActiveRecord::Migration[8.0]
  def change
    create_table :settings_social_autoposts do |t|
      t.string :var, null: false
      t.text :value
      t.bigint :subforem_id
      t.timestamps
    end

    create_table :social_autopost_items do |t|
      t.references :article, null: false, foreign_key: { on_delete: :cascade }, index: false
      # auto: picked by the rating rules, manual: added by an admin,
      # digest: the weekly "top posts" digest article.
      t.string :source, null: false, default: "auto"
      # Which message template to use: community, staff or digest.
      t.string :kind, null: false, default: "community"
      # queued, sending, posted, skipped, failed
      t.string :status, null: false, default: "queued"
      t.integer :priority, null: false, default: 0
      t.text :custom_message
      t.text :sent_message
      t.datetime :post_after
      t.datetime :posted_at
      t.string :telegram_message_id
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.string :skip_reason
      t.timestamps
    end
  end
end
