class AddMonobankFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :monobank_customer_id, :string
    add_column :users, :monobank_subscription_id, :string
    add_index :users, :monobank_customer_id
    add_index :users, :monobank_subscription_id
  end
end
