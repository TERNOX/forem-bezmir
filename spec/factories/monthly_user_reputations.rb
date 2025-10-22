FactoryBot.define do
  factory :monthly_user_reputation do
    association :user
    period { Date.current.beginning_of_month }
    score { 10 }
    rank { 1 }
  end
end
