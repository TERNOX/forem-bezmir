class AddReputationScoreToOrganizations < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :reputation_score, :integer, null: false, default: 0
    add_index :organizations, :reputation_score
  end
end
