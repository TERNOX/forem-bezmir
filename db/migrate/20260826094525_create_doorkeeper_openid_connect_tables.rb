# Nonce storage for OpenID Connect authorization requests.
#
# The relying party sends a nonce with the authorization request and expects it
# back inside the id_token; this table carries it from one to the other.
class CreateDoorkeeperOpenidConnectTables < ActiveRecord::Migration[8.0]
  def change
    create_table :oauth_openid_requests do |t|
      t.references :access_grant, null: false, index: true
      t.string :nonce, null: false
    end

    # strong_migrations asks for `validate: false` plus a follow-up validation
    # migration, because validating a foreign key locks an existing table. This
    # table is created a few lines above and holds no rows, so there is nothing
    # to lock and nothing to validate later.
    safety_assured do
      add_foreign_key(
        :oauth_openid_requests,
        :oauth_access_grants,
        column: :access_grant_id,
        on_delete: :cascade,
      )
    end
  end
end
