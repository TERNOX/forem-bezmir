class ExtendTopSevenArticleSelections < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    add_column :top_seven_article_selections, :frequency, :string, null: false, default: "weekly"
    add_column :top_seven_article_selections, :digest_article_id, :integer
    add_column :top_seven_article_selections, :badge_slug, :string

    if index_exists?(:top_seven_article_selections, :week_of)
      remove_index :top_seven_article_selections, column: :week_of
    end

    add_index :top_seven_article_selections,
              %i[week_of frequency],
              unique: true,
              name: "index_top_seven_article_selections_on_period",
              algorithm: :concurrently
  end

  def down
    remove_index :top_seven_article_selections, name: "index_top_seven_article_selections_on_period"

    add_index :top_seven_article_selections,
              :week_of,
              unique: true,
              name: "index_top_seven_article_selections_on_week_of",
              algorithm: :concurrently unless index_exists?(:top_seven_article_selections, :week_of)

    remove_column :top_seven_article_selections, :badge_slug
    remove_column :top_seven_article_selections, :digest_article_id
    remove_column :top_seven_article_selections, :frequency
  end
end
