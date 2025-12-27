class CatalogItem < ApplicationRecord
  include Taggable

  acts_as_taggable_on :tags

  belongs_to :subforem
  belongs_to :user
  has_many :catalog_field_values, dependent: :destroy, inverse_of: :catalog_item

  accepts_nested_attributes_for :catalog_field_values

  mount_uploader :cover_image, CatalogCoverUploader

  validates :title, presence: true

  before_validation :apply_field_tags

  scope :published, -> { where(published: true) }
  scope :from_subforem, ->(subforem_id = nil) {
    subforem_id ||= RequestStore.store[:subforem_id]
    where(subforem_id: subforem_id)
  }

  def field_value_for(definition)
    catalog_field_values.find { |value| value.catalog_field_definition_id == definition.id }
  end

  private

  def apply_field_tags
    tag_values = catalog_field_values.filter_map do |field_value|
      definition = field_value.catalog_field_definition
      next if definition&.file?
      next if field_value.value_string.blank?

      field_value.value_string.to_s.split(",").map(&:strip).reject(&:blank?)
    end

    self.tag_list = tag_values.flatten.uniq
  end
end
