class AddMonobankFieldsToUsers < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :users, :monobank_customer_id, :string
    add_column :users, :monobank_subscription_id, :string
    add_index :users, :monobank_customer_id, algorithm: :concurrently
    add_index :users, :monobank_subscription_id, algorithm: :concurrently
  end
end
