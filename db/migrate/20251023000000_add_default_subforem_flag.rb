class AddDefaultSubforemFlag < ActiveRecord::Migration[7.1]
  def up
    add_column :subforems, :default_subforem, :boolean, default: false, null: false

    return unless defined?(Subforem)

    Subforem.reset_column_information
    Subforem.order(:id).limit(1).update_all(default_subforem: true) if Subforem.exists?
  end

  def down
    remove_column :subforems, :default_subforem
  end
end
