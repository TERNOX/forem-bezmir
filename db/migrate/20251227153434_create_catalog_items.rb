class CreateCatalogItems < ActiveRecord::Migration[6.1]
  def change
    create_table :catalog_items do |t|
      t.references :subforem, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :cover_image
      t.boolean :published, null: false, default: true

      t.timestamps
    end

    add_index :catalog_items, %i[subforem_id published created_at]
  end
end
