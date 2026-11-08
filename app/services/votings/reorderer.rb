# Fork-only: moves a category/nominee one step up or down among its siblings and
# renumbers positions densely (0..n-1), so legacy duplicates sort out too.
module Votings
  class Reorderer
    def self.move(record, siblings:, direction:)
      ordered = siblings.reorder(:position, :id).to_a
      index = ordered.index(record)
      return unless index

      target = direction.to_s == "up" ? index - 1 : index + 1
      return if target.negative? || target >= ordered.size

      ordered[index], ordered[target] = ordered[target], ordered[index]
      record.class.transaction do
        ordered.each_with_index do |item, position|
          item.update_column(:position, position) if item.position != position
        end
      end
    end
  end
end
