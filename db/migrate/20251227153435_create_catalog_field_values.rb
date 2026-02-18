class CreateCatalogFieldValues < ActiveRecord::Migration[6.1]
  def change
    create_table :catalog_field_values do |t|
      t.references :catalog_item, null: false, foreign_key: true
      t.references :catalog_field_definition, null: false, foreign_key: true
      t.string :value_string
      t.string :file

      t.timestamps
    end

    add_index :catalog_field_values, %i[catalog_item_id catalog_field_definition_id],
              unique: true,
              name: "index_catalog_field_values_on_item_and_definition"
  end
end
