class AddFavoriteCreditsRefreshedAtToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :favorite_credits_refreshed_at, :datetime
  end
end
