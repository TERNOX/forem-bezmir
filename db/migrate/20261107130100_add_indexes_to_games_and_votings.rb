class AddIndexesToGamesAndVotings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :games, :igdb_id, unique: true, where: "igdb_id IS NOT NULL",
                                algorithm: :concurrently, if_not_exists: true
    add_index :games, "lower(title)", name: "index_games_on_lower_title",
                                      algorithm: :concurrently, if_not_exists: true

    add_index :votings, :slug, unique: true, algorithm: :concurrently, if_not_exists: true

    add_index :voting_categories, %i[voting_id position], algorithm: :concurrently, if_not_exists: true

    add_index :voting_nominees, %i[voting_category_id position], algorithm: :concurrently, if_not_exists: true
    add_index :voting_nominees, :game_id, algorithm: :concurrently, if_not_exists: true

    add_index :voting_ballots, %i[voting_id user_id], unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :voting_ballots, :user_id, algorithm: :concurrently, if_not_exists: true

    add_index :voting_choices, %i[voting_ballot_id voting_category_id],
              name: "index_voting_choices_on_ballot_and_category", algorithm: :concurrently, if_not_exists: true
    add_index :voting_choices, :voting_category_id, algorithm: :concurrently, if_not_exists: true
    add_index :voting_choices, :voting_nominee_id, algorithm: :concurrently, if_not_exists: true
  end
end
