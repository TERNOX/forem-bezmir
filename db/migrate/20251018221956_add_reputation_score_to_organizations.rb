class AddReputationScoreToOrganizations < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :reputation_score, :integer, default: 0, null: false
    add_index :organizations, :reputation_score
  end
end
