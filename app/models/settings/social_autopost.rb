module Settings
  # Fork-only: automatic posting of community articles to a Telegram channel.
  # See SocialAutopost::Ticker for how the queue and schedule work.
  class SocialAutopost < Base
    self.table_name = :settings_social_autoposts

    QUEUE_ORDERS = %w[score oldest newest].freeze
    DIGEST_TIMINGS = %w[immediately next_slot].freeze
    WEEKDAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze
    DEFAULT_OFFICIAL_ORGANIZATION_IDS = [1, 2].freeze

    setting :enabled, type: :boolean, default: false

    # Telegram
    setting :telegram_bot_token, type: :string
    setting :telegram_chat_id, type: :string
    setting :disable_link_preview, type: :boolean, default: false

    # Which articles get queued automatically
    setting :minimum_score, type: :integer, default: 15
    setting :minimum_reactions, type: :integer, default: 0
    setting :max_age_days, type: :integer, default: 30
    setting :include_community_favorites, type: :boolean, default: true
    setting :include_staff_posts, type: :boolean, default: true
    setting :include_official_posts, type: :boolean, default: false
    setting :official_organization_ids, type: :array, default: DEFAULT_OFFICIAL_ORGANIZATION_IDS
    setting :staff_usernames, type: :array, default: %w[]
    setting :published_after, type: :string
    # Reuse the "posts of the week" digest quality filters (minimum length,
    # excluded tags). When off, the two settings below apply instead.
    setting :use_digest_filters, type: :boolean, default: true
    setting :minimum_body_length, type: :integer, default: 300
    setting :excluded_tags, type: :array, default: %w[]
    # Video posts need real text next to the video to qualify.
    setting :minimum_video_body_length, type: :integer, default: 500
    setting :queue_order, type: :string, default: "score", validates: { inclusion: { in: QUEUE_ORDERS } }

    # Schedule (Kyiv time). Each day takes comma-separated windows like "19:00-21:30".
    setting :schedule_monday, type: :string, default: "19:00-21:30"
    setting :schedule_tuesday, type: :string, default: "19:00-21:30"
    setting :schedule_wednesday, type: :string, default: "19:00-21:30"
    setting :schedule_thursday, type: :string, default: "19:00-21:30"
    setting :schedule_friday, type: :string, default: "19:00-21:30"
    setting :schedule_saturday, type: :string, default: "13:00-22:00"
    setting :schedule_sunday, type: :string, default: "13:00-22:00"
    setting :min_interval_minutes, type: :integer, default: 120
    setting :random_delay_minutes, type: :integer, default: 0
    setting :max_posts_per_day, type: :integer, default: 0

    # "Posts of the week" digest
    setting :post_digest, type: :boolean, default: true
    setting :digest_timing, type: :string, default: "immediately", validates: { inclusion: { in: DIGEST_TIMINGS } }

    # Message templates. Blank means the localized default.
    setting :template_community, type: :string
    setting :template_staff, type: :string
    setting :template_digest, type: :string

    # Runtime state
    setting :next_post_not_before, type: :string
    setting :last_error, type: :string
    setting :last_error_at, type: :string
  end
end
