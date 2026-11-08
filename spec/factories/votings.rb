# Fork-only: votings ("Гра року").
FactoryBot.define do
  factory :game do
    sequence(:title) { |n| "Game #{n}" }
    release_year { 2026 }
  end

  factory :voting do
    sequence(:title) { |n| "Гра року #{n}" }
    sequence(:slug) { |n| "gra-roku-#{n}" }
    published { true }
    opens_at { 1.day.ago }
    closes_at { 1.week.from_now }
  end

  factory :voting_category do
    voting
    sequence(:title) { |n| "Nomination #{n}" }
    max_choices { 1 }
  end

  factory :voting_nominee do
    category factory: %i[voting_category]
    game
  end

  factory :voting_ballot do
    voting
    user
    submitted_at { Time.current }
  end
end
