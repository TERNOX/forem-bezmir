class CatalogFieldDefinition < ApplicationRecord
  FIELD_TYPES = %w[text link file tag].freeze

  belongs_to :subforem
  has_many :catalog_field_values, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :subforem_id }
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :from_subforem, ->(subforem_id = nil) {
    subforem_id ||= RequestStore.store[:subforem_id]
    where(subforem_id: subforem_id)
  }

  def file?
    field_type == "file"
  end

  def link?
    field_type == "link"
  end

  def tag?
    field_type == "tag"
  end
end
