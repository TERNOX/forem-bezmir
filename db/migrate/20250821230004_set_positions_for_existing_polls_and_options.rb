class SetPositionsForExistingPollsAndOptions < ActiveRecord::Migration[7.0]
  # Migration-local models without the real models' enums. Rails 7.1 raises
  # "Undeclared attribute type for enum" when the real Survey/Poll models load
  # against a schema where the enum-backing columns don't exist yet (they're
  # added by later migrations), so we use bare AR classes here.
  class MigrationSurvey < ActiveRecord::Base
    self.table_name = "surveys"
    has_many :polls, class_name: "SetPositionsForExistingPollsAndOptions::MigrationPoll", foreign_key: :survey_id
  end

  class MigrationPoll < ActiveRecord::Base
    self.table_name = "polls"
    has_many :poll_options, class_name: "SetPositionsForExistingPollsAndOptions::MigrationPollOption", foreign_key: :poll_id
  end

  class MigrationPollOption < ActiveRecord::Base
    self.table_name = "poll_options"
  end

  def up
    # Set positions for polls within each survey based on creation order
    MigrationSurvey.find_each do |survey|
      survey.polls.order(:created_at).each_with_index do |poll, index|
        poll.update_column(:position, index)
      end
    end

    # Set positions for poll options within each poll based on creation order
    MigrationPoll.find_each do |poll|
      poll.poll_options.order(:created_at).each_with_index do |option, index|
        option.update_column(:position, index)
      end
    end
  end

  def down
    # No need to revert positions as they're just ordering
  end
end
