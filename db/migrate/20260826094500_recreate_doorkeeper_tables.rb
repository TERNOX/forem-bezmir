# Doorkeeper tables — this Forem instance acts as an OAuth 2 / OIDC provider
# so that federated sites can offer "sign in with this community".
#
# NOTE: doorkeeper used to live here and was dropped in 2021
# (20211222040359_remove_doorkeeper). This re-creates the tables with the
# current doorkeeper 5.9 schema rather than reverting that migration, so the
# history stays append-only and the old columns (which no longer match the
# gem) are not resurrected.
#
# Indexes are declared inline: these tables are brand new and empty, so the
# `algorithm: :concurrently` rule (AGENTS.md) — which exists to avoid locking
# populated tables — does not apply here.
# Renamed from CreateDoorkeeperTables: the 2019 migration of that name is
# still in history, and Rails refuses two migration classes with the same
# name when dumping the schema.
class RecreateDoorkeeperTables < ActiveRecord::Migration[8.0]
  def change
    create_table :oauth_applications do |t|
      t.string :name, null: false
      t.string :uid, null: false
      t.string :secret, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :confidential, null: false, default: true
      t.timestamps null: false
    end

    add_index :oauth_applications, :uid, unique: true

    create_table :oauth_access_grants do |t|
      t.bigint :resource_owner_id, null: false
      t.references :application, null: false
      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.datetime :created_at, null: false
      t.datetime :revoked_at
    end

    add_index :oauth_access_grants, :token, unique: true
    add_index :oauth_access_grants, :resource_owner_id

    # strong_migrations asks for `validate: false` plus a follow-up validation
    # migration, because validating a foreign key locks an existing table.
    # These tables are created a few lines above and hold no rows, so there is
    # nothing to lock and nothing to validate later.
    #
    # Deleting a user takes their grants and tokens with them: otherwise a
    # token would stay valid while pointing at nobody.
    safety_assured do
      add_foreign_key :oauth_access_grants, :oauth_applications, column: :application_id, on_delete: :cascade
      add_foreign_key :oauth_access_grants, :users, column: :resource_owner_id, on_delete: :cascade
    end

    create_table :oauth_access_tokens do |t|
      t.bigint :resource_owner_id
      t.references :application, null: false
      t.string :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.datetime :revoked_at
      t.datetime :created_at, null: false
      t.string :scopes
      t.string :previous_refresh_token, null: false, default: ""
    end

    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :refresh_token, unique: true
    add_index :oauth_access_tokens, :resource_owner_id

    safety_assured do
      add_foreign_key :oauth_access_tokens, :oauth_applications, column: :application_id, on_delete: :cascade
      add_foreign_key :oauth_access_tokens, :users, column: :resource_owner_id, on_delete: :cascade
    end
  end
end
