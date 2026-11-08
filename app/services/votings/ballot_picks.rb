# Fork-only: a ballot's answers grouped per nomination, in voting order.
module Votings
  class BallotPicks
    Pick = Struct.new(:category, :nominees, :other, keyword_init: true)

    # @return [Array<Pick>] only nominations the voter answered
    def self.call(ballot, categories = ballot.voting.categories.includes(nominees: :game).to_a)
      choices = ballot.choices.to_a.group_by(&:voting_category_id)
      categories.filter_map do |category|
        category_choices = choices[category.id]
        next if category_choices.blank?

        nominees_by_id = category.nominees.index_by(&:id)
        nominees = category_choices.select(&:voting_nominee_id).sort_by { |c| c.rank || 0 }
          .filter_map { |c| nominees_by_id[c.voting_nominee_id] }
        other = category_choices.detect { |c| c.voting_nominee_id.nil? }&.other_text
        next if nominees.empty? && other.blank?

        Pick.new(category: category, nominees: nominees, other: other)
      end
    end
  end
end
