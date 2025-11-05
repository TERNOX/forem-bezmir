class AddTargetOrganizationIdsToDisplayAds < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :display_ads, :target_organization_ids, :integer, array: true, default: [], null: false
    add_index :display_ads, :target_organization_ids, using: :gin, algorithm: :concurrently
  end
end
