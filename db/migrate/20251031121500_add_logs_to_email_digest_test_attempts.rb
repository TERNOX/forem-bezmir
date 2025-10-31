class AddLogsToEmailDigestTestAttempts < ActiveRecord::Migration[7.0]
  def change
    add_column :email_digest_test_attempts, :status_note, :text

    create_table :email_digest_test_attempt_logs do |t|
      t.references :email_digest_test_attempt, null: false, foreign_key: true, index: { name: "index_digest_attempt_logs_on_attempt_id" }
      t.string :level, null: false, default: "info"
      t.text :message, null: false
      t.jsonb :context, null: false, default: {}

      t.timestamps
    end

    add_index :email_digest_test_attempt_logs, :created_at
    add_index :email_digest_test_attempt_logs, :level
  end
end
