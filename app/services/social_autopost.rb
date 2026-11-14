# Fork-only: automatic posting of community articles to a Telegram channel
# (the channel's own crossposting then spreads them to the site's other social
# networks). Articles enter a queue once they reach a rating threshold and are
# posted inside configured time windows with a minimum gap between posts. The
# weekly "top posts" digest is posted right after the bot publishes it.
module SocialAutopost
  module_function

  def configured?
    Settings::SocialAutopost.telegram_bot_token.present? && Settings::SocialAutopost.telegram_chat_id.present?
  end

  def active?
    Settings::SocialAutopost.enabled && configured?
  end

  def official_organization_ids
    Array(Settings::SocialAutopost.official_organization_ids).filter_map do |value|
      value.to_i if value.to_i.positive?
    end.uniq
  end

  def staff_usernames
    Array(Settings::SocialAutopost.staff_usernames).map { |name| name.to_s.strip.delete_prefix("@").downcase }
      .compact_blank.uniq
  end

  def staff_user_ids
    admin_ids = User.with_any_role(*Authorizer::RoleBasedQueries::ANY_ADMIN_ROLES).map(&:id)
    named_ids = staff_usernames.empty? ? [] : User.where("lower(username) IN (?)", staff_usernames).ids
    (admin_ids + named_ids).uniq
  end

  # Which message template an article gets: "staff" for admins, people listed
  # as staff and the official organizations, "community" for everyone else.
  def kind_for(article)
    return "staff" if article.organization_id.present? && article.organization_id.in?(official_organization_ids)

    user = article.user
    return "community" unless user
    return "staff" if user.any_admin? || user.username.to_s.downcase.in?(staff_usernames)

    "community"
  end

  # Authors (user ids) who already had an article posted in the given range.
  def posted_author_ids(range)
    SocialAutopostItem.posted.where(posted_at: range).joins(:article).distinct.pluck("articles.user_id")
  end

  # With one_post_per_author_per_day, community items whose author is in
  # +author_ids+ wait for another day; staff and digest items never do.
  def author_waits?(item, author_ids)
    Settings::SocialAutopost.one_post_per_author_per_day && item.kind == "community" &&
      item.article&.user_id.in?(author_ids)
  end

  # After any post, the next scheduled one waits at least the minimum
  # interval (plus the optional random delay).
  def push_back_next_post!(now)
    gap = [Settings::SocialAutopost.min_interval_minutes.to_i, 0].max.minutes
    jitter = Settings::SocialAutopost.random_delay_minutes.to_i
    gap += rand(0..jitter).minutes if jitter.positive?
    candidate = now + gap

    current = Settings::SocialAutopost.next_post_not_before.presence
    current &&= Time.zone.parse(current)
    return if current && current > candidate

    Settings::SocialAutopost.next_post_not_before = candidate.iso8601
  rescue ArgumentError
    Settings::SocialAutopost.next_post_not_before = candidate.iso8601
  end

  # True while Telegram's 429 cooldown (retry_after) is still running.
  def rate_limited?(now)
    value = Settings::SocialAutopost.rate_limited_until.presence
    value.present? && Time.zone.parse(value) > now
  rescue ArgumentError
    false
  end

  def unpostable_author?(user)
    user.nil? || user.spam? || user.suspended?
  end

  # Readable one-line description of an error for the admin page, with the
  # bot token masked (some errors quote the API URL, which contains it).
  def describe_error(error)
    message = error.is_a?(TelegramClient::Error) ? error.message : "#{error.class}: #{error.message}"
    token = Settings::SocialAutopost.telegram_bot_token.to_s.strip
    message = message.gsub(token, "[bot token]") if token.present?
    message.squish.truncate(500)
  end

  # Shows the error in the "Last error" banner of the admin page.
  def record_error!(error, now: Time.current)
    Settings::SocialAutopost.last_error = describe_error(error)
    Settings::SocialAutopost.last_error_at = now.iso8601
  end
end
