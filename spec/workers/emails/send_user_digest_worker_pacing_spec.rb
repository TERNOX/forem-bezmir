require "rails_helper"
require "sidekiq/scheduled"

RSpec.describe Emails::SendUserDigestWorker, type: :worker do
  let(:user) { create(:user) }
  let(:articles) { create_list(:article, 3) }
  let(:collector) { instance_double(EmailDigestArticleCollector, articles_to_send: articles) }
  let(:mailer) { double }
  let(:delivery) { double }

  before do
    user.notification_setting.update!(email_digest_periodic: true)
    allow(EmailDigestArticleCollector).to receive(:new).and_return(collector)
    allow(DigestMailer).to receive(:with).and_return(mailer)
    allow(mailer).to receive(:digest_email).and_return(delivery)
    allow(delivery).to receive(:deliver_now)
  end

  it "does not consume a delivery slot when the collector skips a user" do
    allow(collector).to receive(:articles_to_send).and_return([])

    described_class.new.perform(user.id)

    expect(Sidekiq.redis { |redis| redis.get(described_class::DELIVERY_SLOT_KEY) }).to be_nil
    expect(delivery).not_to have_received(:deliver_now)
  end

  it "does not throttle jobs during fetching from the shared queue" do
    expect(Sidekiq::Throttled::Registry.get(described_class)).to be_nil
  end

  it "defers an eligible delivery with its options when another delivery holds the slot" do
    Sidekiq.redis { |redis| redis.set(described_class::DELIVERY_SLOT_KEY, "another-user") }
    allow(described_class).to receive(:perform_in)

    described_class.new.perform(user.id, "source" => "regression")

    interval = described_class::DELIVERY_INTERVAL
    expect(described_class).to have_received(:perform_in).with(
      a_value_between(interval, (interval * 2) - 1), user.id, "source" => "regression"
    )
    expect(delivery).not_to have_received(:deliver_now)
  end

  it "reserves an expiring slot before sending a digest" do
    described_class.new.perform(user.id)

    expect(delivery).to have_received(:deliver_now).once
    expect(Sidekiq.redis { |redis| redis.ttl(described_class::DELIVERY_SLOT_KEY) })
      .to be_between(1, described_class::DELIVERY_INTERVAL)
  end

  # The uniqueness Lua scripts require real Redis, not fakeredis.
  # Run with DIGEST_PACING_TEST_REDIS_URL pointing to an empty disposable database.
  context "with real Redis" do
    let(:real_redis) { Redis.new(url: ENV.fetch("DIGEST_PACING_TEST_REDIS_URL"), driver: :ruby) }
    let(:pool) { ConnectionPool.new(size: 1) { real_redis } }

    before do
      allow(Sidekiq).to receive(:redis_pool).and_return(pool)
      SidekiqUniqueJobs.config.enabled = true
    end

    around do |example|
      skip "Set DIGEST_PACING_TEST_REDIS_URL to run the middleware integration" unless
        ENV["DIGEST_PACING_TEST_REDIS_URL"]

      redis = real_redis
      raise "Integration test requires an empty Redis database" unless redis.dbsize.zero?

      unique_enabled = SidekiqUniqueJobs.config.enabled
      begin
        Sidekiq::Testing.disable! { example.run }
      ensure
        SidekiqUniqueJobs.config.enabled = unique_enabled
        # The database was empty on entry; these keys belong to this example.
        keys = redis.keys("*")
        redis.del(*keys) if keys.any?
        redis.close
      end
    end

    it "retains a deferred unique job and delivers it after the slot expires" do
      real_redis.set(described_class::DELIVERY_SLOT_KEY, "another-user", ex: described_class::DELIVERY_INTERVAL)
      jid = described_class.perform_async(user.id, "source" => "regression")
      expect(jid).to be_present
      expect(described_class.perform_async(user.id, "source" => "regression")).to be_nil

      execute_queued_digest

      scheduled = Sidekiq::ScheduledSet.new.to_a
      expect(scheduled.size).to eq(1)
      expect(scheduled.first.args).to eq([user.id, { "source" => "regression" }])
      expect(delivery).not_to have_received(:deliver_now)

      real_redis.expire(described_class::DELIVERY_SLOT_KEY, 0)
      Timecop.travel(((described_class::DELIVERY_INTERVAL * 2) + 1).seconds.from_now) do
        Sidekiq::Scheduled::Enq.new.enqueue_jobs
        execute_queued_digest
      end

      expect(delivery).to have_received(:deliver_now).once
      expect(Sidekiq::ScheduledSet.new.size).to eq(0)
    end

    def execute_queued_digest
      job = Sidekiq.load_json(real_redis.rpop("queue:low_priority"))
      worker = described_class.new
      chain = Sidekiq::Middleware::Chain.new
      chain.add SidekiqUniqueJobs::Middleware::Client
      chain.add SidekiqUniqueJobs::Middleware::Server
      chain.invoke(worker, job, "low_priority") { worker.perform(*job.fetch("args")) }
    end
  end
end
