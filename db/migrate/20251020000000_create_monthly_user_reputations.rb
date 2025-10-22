class CreateMonthlyUserReputations < ActiveRecord::Migration[7.1]
  def change
    create_table :monthly_user_reputations do |t|
      t.references :user, null: false, foreign_key: true
      t.date :period, null: false
      t.integer :score, null: false, default: 0
      t.integer :rank
      t.datetime :awarded_top_ten_at

      t.timestamps
    end

    add_index :monthly_user_reputations, :period
    add_index :monthly_user_reputations, [:period, :user_id], unique: true
  end
end
