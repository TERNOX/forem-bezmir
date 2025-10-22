class CreateTopSevenArticleSelections < ActiveRecord::Migration[7.0]
  def change
    create_table :top_seven_article_selections do |t|
      t.date :week_of, null: false
      t.integer :article_ids, array: true, default: [], null: false
      t.datetime :awarded_at

      t.timestamps
    end

    add_index :top_seven_article_selections, :week_of, unique: true
  end
end
