# Fork-only: a ballot's share pictures are now two files, both drawn by
# Votings::GenerateShareImage: the tall vote card (share_image, the picture
# people download) and a 1200x630 link preview (og:image). nil = not drawn yet.
class AddSharePreviewImageToVotingBallots < ActiveRecord::Migration[8.0]
  def up
    add_column :voting_ballots, :share_preview_image, :string
  end

  def down
    # Dropping the column this migration added is the whole rollback.
    safety_assured { remove_column :voting_ballots, :share_preview_image }
  end
end
