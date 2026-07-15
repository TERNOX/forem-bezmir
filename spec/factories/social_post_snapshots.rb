FactoryBot.define do
  factory :social_post_snapshot do
    platform { "bluesky" }
    sequence(:source_id) { |n| "post#{n}" }
    source_url { "https://bsky.app/profile/alice.bsky.social/post/#{source_id}" }
    at_uri { "at://did:plc:abc123/app.bsky.feed.post/#{source_id}" }
    author_handle { "alice.bsky.social" }
    author_name { "Alice" }
    text_content { "Hello world" }
    text_html { "Hello world" }
    posted_at { Time.current }
    source_status { :live }
    fetched_at { Time.current }
    checked_at { Time.current }

    trait :twitter do
      platform { "twitter" }
      source_url { "https://twitter.com/i/status/#{source_id}" }
      at_uri { nil }
    end

    trait :archived do
      source_status { :deleted }
    end

    trait :with_photo do
      media { [{ "type" => "photo", "url" => "https://cdn.example.com/a.jpg", "source_url" => "https://src/a.jpg", "alt" => "" }] }
    end
  end
end
