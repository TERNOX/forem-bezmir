# Fork-only feature: "Гра року"-style votings with a shared game catalog.
# Indexes live in 20261107130100_add_indexes_to_games_and_votings (added concurrently).
class CreateGamesAndVotings < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :title, null: false
      t.bigint :igdb_id
      t.string :igdb_url
      t.integer :release_year
      t.string :platforms, array: true, default: [], null: false
      t.string :igdb_cover_image_id
      t.string :igdb_artwork_image_id
      t.string :cover_image
      t.string :artwork_image
      t.timestamps
    end

    create_table :votings do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description_markdown
      t.text :description_html
      t.string :banner_image
      t.datetime :opens_at
      t.datetime :closes_at
      t.boolean :published, default: false, null: false
      t.datetime :results_published_at
      t.boolean :top_level_path, default: false, null: false
      t.boolean :require_account_before_start, default: false, null: false
      t.integer :min_user_score, default: 0, null: false
      t.timestamps
    end

    create_table :voting_categories do |t|
      t.references :voting, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :title, null: false
      t.text :description
      t.integer :position, default: 0, null: false
      t.integer :max_choices, default: 1, null: false
      t.boolean :required, default: false, null: false
      t.boolean :ranked, default: false, null: false
      t.boolean :allow_other, default: false, null: false
      t.integer :card_style, default: 0, null: false
      t.timestamps
    end

    create_table :voting_nominees do |t|
      t.references :voting_category, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :game, foreign_key: { on_delete: :restrict }, index: false
      t.string :title
      t.string :subtitle
      t.string :link_url
      t.string :image
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    create_table :voting_ballots do |t|
      t.references :voting, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.datetime :submitted_at
      t.string :share_image
      t.timestamps
    end

    create_table :voting_choices do |t|
      t.references :voting_ballot, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :voting_category, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :voting_nominee, foreign_key: { on_delete: :cascade }, index: false
      t.integer :rank
      t.string :other_text
      t.timestamps
    end
  end
end
