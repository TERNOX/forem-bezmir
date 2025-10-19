class AddReputationScoreToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :reputation_score, :integer, null: false, default: 0
  end
end
