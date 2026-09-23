module Emails
  class DigestDeliveryLimiter
    INTERVAL = [ENV.fetch("EMAIL_DIGEST_INTERVAL_SECONDS", 60).to_i, 1].max
    NEXT_SLOT_KEY = "email_digest/next_delivery_slot".freeze
    ACTIVE_SLOT_KEY = "email_digest/active_delivery_slot".freeze

    # Allocate distinct future slots, but also guard actual sends: delayed jobs
    # must not burst together after a worker outage. Both operations are atomic.
    RESERVE_OR_CLAIM = <<~LUA.freeze
      local now = tonumber(ARGV[1])
      local interval = tonumber(ARGV[2])
      local reserved = tonumber(ARGV[3])
      if reserved > now then return reserved end

      local next_slot = tonumber(redis.call('GET', KEYS[1])) or now
      if (reserved > 0 or next_slot <= now) and
          redis.call('SET', KEYS[2], '1', 'NX', 'EX', interval) then
        local following = math.max(next_slot, now + interval)
        redis.call('SET', KEYS[1], following, 'EX', following - now)
        return 0
      end

      local slot = math.max(next_slot, now + interval)
      redis.call('SET', KEYS[1], slot + interval, 'EX', slot + interval - now)
      return slot
    LUA

    def self.call(reserved_at: nil)
      slot = Sidekiq.redis do |redis|
        redis.eval(
          RESERVE_OR_CLAIM,
          keys: [NEXT_SLOT_KEY, ACTIVE_SLOT_KEY], argv: [Time.current.to_i, INTERVAL, reserved_at.to_i]
        )
      end
      slot.zero? ? nil : slot
    end
  end
end
