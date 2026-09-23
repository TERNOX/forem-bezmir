require "rails_helper"
require "sidekiq/fetch"

RSpec.describe Emails::SendUserDigestWorker, type: :worker do
  let(:strategy) { Sidekiq::Throttled::Registry.get(described_class) }
  let(:payload) do
    { "class" => described_class.name, "args" => [123], "jid" => SecureRandom.hex(12),
      "queue" => "low_priority", "lock" => "until_executing", "retry" => 15 }
  end

  it "requeues throttled work with its original identity and retry metadata" do
    work = Sidekiq::BasicFetch::UnitOfWork.new("queue:low_priority", Sidekiq.dump_json(payload))

    strategy.requeue_throttled(work)

    requeued = Sidekiq.redis { |redis| redis.rpop("queue:low_priority") }
    expect(Sidekiq.load_json(requeued)).to eq(payload)
  end

  # Lua-based uniqueness and throttle locks require real Redis, not fakeredis.
  # Run with DIGEST_THROTTLE_TEST_REDIS_URL pointing to an empty disposable database.
  context "with real Redis" do
    let(:real_redis) { Redis.new(url: ENV.fetch("DIGEST_THROTTLE_TEST_REDIS_URL"), driver: :ruby) }
    let(:pool) { ConnectionPool.new(size: 1) { real_redis } }

    before do
      allow(Sidekiq).to receive(:redis_pool).and_return(pool)
    end

    around do |example|
      skip "Set DIGEST_THROTTLE_TEST_REDIS_URL to run the middleware integration" unless
        ENV["DIGEST_THROTTLE_TEST_REDIS_URL"]

      redis = real_redis
      raise "Integration test requires an empty Redis database" unless redis.dbsize.zero?

      unique_enabled = SidekiqUniqueJobs.config.enabled
      SidekiqUniqueJobs.config.enabled = true
      begin
        Sidekiq::Testing.disable! { example.run }
      ensure
        SidekiqUniqueJobs.config.enabled = unique_enabled
        # This database was verified empty before the test; remove only test-created keys.
        keys = redis.keys("*")
        redis.del(*keys) if keys.any?
        redis.close
      end
    end

    it "executes a throttled unique job after the interval without dropping it" do
      jid = described_class.perform_async(123)
      raw = Sidekiq.redis { |redis| redis.rpop("queue:low_priority") }
      work = Sidekiq::BasicFetch::UnitOfWork.new("queue:low_priority", raw)
      job = Sidekiq.load_json(raw)

      expect(jid).to be_present
      expect(described_class.perform_async(123)).to be_nil
      expect(strategy.throttled?("previous-digest", 456)).to be(false)
      strategy.finalize!("previous-digest", 456)
      expect(Sidekiq::Throttled.throttled?(raw)).to be(true)

      Sidekiq::Throttled.requeue_throttled(work)
      expect(Sidekiq::ScheduledSet.new.size).to eq(0)
      requeued = Sidekiq.redis { |redis| redis.rpop("queue:low_priority") }
      expect(requeued).to eq(raw)

      Timecop.travel(ENV.fetch("EMAIL_DIGEST_INTERVAL_SECONDS", 60).to_i.seconds.from_now + 1.second) do
        expect(Sidekiq::Throttled.throttled?(requeued)).to be(false)
        executed = false
        chain = Sidekiq::Middleware::Chain.new
        chain.add Sidekiq::Throttled::Middlewares::Server
        chain.add SidekiqUniqueJobs::Middleware::Client
        chain.add SidekiqUniqueJobs::Middleware::Server
        chain.invoke(described_class.new, job, "low_priority") { executed = true }

        expect(executed).to be(true)
        expect(described_class.perform_async(123)).to be_present
      end
    end
  end
end
