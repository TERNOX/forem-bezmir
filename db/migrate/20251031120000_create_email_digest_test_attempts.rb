class CreateEmailDigestTestAttempts < ActiveRecord::Migration[7.0]
  def change
    create_table :email_digest_test_attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :job_id
      t.text :error_message
      t.string :honeybadger_id

      t.timestamps
    end

    add_index :email_digest_test_attempts, :created_at
    add_index :email_digest_test_attempts, :status
  end
end
