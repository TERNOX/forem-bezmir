class AddShowBorderToDisplayAds < ActiveRecord::Migration[7.2]
  def change
    add_column :display_ads, :show_border, :boolean, default: true, null: false
  end
end
