# Fork-only feature: durable snapshots of embedded social posts (Twitter/X, Bluesky)
# so that articles keep their embedded quote's text + photos even after the original
# post or account is deleted. See app/services/social_embeds/.
class CreateSocialPostSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :social_post_snapshots do |t|
      t.string :platform, null: false
      t.string :source_id, null: false
      t.string :source_url, null: false
      t.string :at_uri
      t.string :author_handle
      t.string :author_name
      t.string :author_avatar_url
      t.text :text_html
      t.text :text_content
      t.datetime :posted_at
      t.jsonb :media, null: false, default: []
      t.jsonb :raw, null: false, default: {}
      t.integer :source_status, null: false, default: 0
      t.datetime :fetched_at
      t.datetime :checked_at

      t.timestamps
    end

    add_index :social_post_snapshots, %i[platform source_id], unique: true
    add_index :social_post_snapshots, :source_status
  end
end
