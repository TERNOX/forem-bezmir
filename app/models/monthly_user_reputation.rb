class MonthlyUserReputation < ApplicationRecord
  belongs_to :user

  scope :for_period, ->(period) { where(period: period) }

  validates :period, presence: true
  validates :score, numericality: { greater_than_or_equal_to: 0 }
end
