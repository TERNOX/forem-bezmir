class CatalogFieldValue < ApplicationRecord
  belongs_to :catalog_item
  belongs_to :catalog_field_definition

  mount_uploader :file, CatalogFileUploader

  validate :required_value_present

  def display_value
    return file.url if catalog_field_definition&.file?

    value_string
  end

  private

  def required_value_present
    return unless catalog_field_definition&.required?

    if catalog_field_definition.file?
      errors.add(:file, "can't be blank") if file.blank?
    else
      errors.add(:value_string, "can't be blank") if value_string.blank?
    end
  end
end
