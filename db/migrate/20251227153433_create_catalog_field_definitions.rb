class CreateCatalogFieldDefinitions < ActiveRecord::Migration[6.1]
  def change
    create_table :catalog_field_definitions do |t|
      t.references :subforem, null: false, foreign_key: true
      t.string :name, null: false
      t.string :field_type, null: false
      t.boolean :required, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :catalog_field_definitions, %i[subforem_id position]
    add_index :catalog_field_definitions, %i[subforem_id name], unique: true
  end
end
