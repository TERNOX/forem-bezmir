require "rails_helper"
require "sidekiq/scheduled"

RSpec.describe Emails::SendUserDigestWorker, type: :worker do
  let(:user) { create(:user) }
  let(:articles) { create_list(:article, 3) }
  let(:collector) { instance_double(EmailDigestArticleCollector, articles_to_send: articles) }
  let(:mailer) { double }
  let(:delivery) { double }

  before do
    allow(Emails::DigestDeliveryLimiter).to receive(:call).and_return(nil)
    user.notification_setting.update!(email_digest_periodic: true)
    allow(EmailDigestArticleCollector).to receive(:new).and_return(collector)
    allow(DigestMailer).to receive(:with).and_return(mailer)
    allow(mailer).to receive(:digest_email).and_return(delivery)
    allow(delivery).to receive(:message)
    allow(delivery).to receive(:deliver_now)
  end

  it "does not consume a delivery slot when the collector skips a user" do
    allow(collector).to receive(:articles_to_send).and_return([])

    described_class.new.perform(user.id)

    expect(Emails::DigestDeliveryLimiter).not_to have_received(:call)
    expect(delivery).not_to have_received(:deliver_now)
  end

  it "does not throttle jobs during fetching from the shared queue" do
    expect(Sidekiq::Throttled::Registry.get(described_class)).to be_nil
  end

  it "uses a dedicated queue consumed by the default Sidekiq configuration" do
    queue = described_class.get_sidekiq_options.fetch("queue").to_s
    configuration = YAML.load_file(Rails.root.join("config/sidekiq.yml"), permitted_classes: [Symbol])

    expect(queue).to eq("email_digest")
    expect(configuration.fetch(:queues)).to include([queue, 1])
  end

  it "defers an eligible delivery with its options when another delivery holds the slot" do
    delivery_at = 1.minute.from_now.to_i
    allow(Emails::DigestDeliveryLimiter).to receive(:call).and_return(delivery_at)
    allow(described_class).to receive(:perform_at)

    described_class.new.perform(user.id, "source" => "regression")

    expect(described_class).to have_received(:perform_at).with(
      delivery_at, user.id, "source" => "regression", "delivery_slot_at" => delivery_at
    )
    expect(delivery).not_to have_received(:deliver_now)
  end

  it "claims its reserved slot before sending a deferred digest" do
    reserved_at = 1.minute.ago.to_i
    described_class.new.perform(user.id, "delivery_slot_at" => reserved_at)

    expect(delivery).to have_received(:deliver_now).once
    expect(Emails::DigestDeliveryLimiter).to have_received(:call).with(reserved_at: reserved_at)
  end

  it "keeps a deferred test digest on the priority mail queue" do
    attempt = EmailDigestTestAttempt.create!(user: user)
    delivery_at = 1.minute.from_now.to_i
    allow(Emails::DigestDeliveryLimiter).to receive(:call).with(reserved_at: nil, priority: true)
      .and_return(delivery_at)

    described_class.new.perform(user.id, test_attempt_id: attempt.id)

    expect(described_class.jobs.last).to include(
      "queue" => "mailers",
      "args" => [user.id, { "test_attempt_id" => attempt.id, "delivery_slot_at" => delivery_at }],
    )
    expect(delivery).not_to have_received(:deliver_now)
  end

  it "lets Sidekiq retry a Redis failure while claiming a delivery slot" do
    allow(Emails::DigestDeliveryLimiter).to receive(:call).and_raise(Redis::CannotConnectError)

    expect { described_class.new.perform(user.id) }.to raise_error(Redis::CannotConnectError)
    expect(delivery).not_to have_received(:deliver_now)
  end

  it "lets Sidekiq retry when enqueueing a deferred delivery fails" do
    allow(Emails::DigestDeliveryLimiter).to receive(:call).and_return(1.minute.from_now.to_i)
    allow(described_class).to receive(:perform_at).and_raise(Redis::CannotConnectError)

    expect { described_class.new.perform(user.id) }.to raise_error(Redis::CannotConnectError)
    expect(delivery).not_to have_received(:deliver_now)
  end

  it "finishes slow preparation before claiming the delivery slot" do
    started_at = Time.current
    claimed_at = nil
    sent_at = nil
    allow(delivery).to receive(:message) { Timecop.travel(started_at + (Emails::DigestDeliveryLimiter::INTERVAL * 2)) }
    allow(Emails::DigestDeliveryLimiter).to receive(:call) do
      claimed_at = Time.current
      nil
    end
    allow(delivery).to receive(:deliver_now) { sent_at = Time.current }

    Timecop.freeze(started_at) { described_class.new.perform(user.id) }

    expect(claimed_at).to be >= started_at + Emails::DigestDeliveryLimiter::INTERVAL
    expect(sent_at - claimed_at).to be < 1
  end

  # The uniqueness Lua scripts require real Redis, not fakeredis.
  # Run with DIGEST_PACING_TEST_REDIS_URL pointing to an empty disposable database.
  context "with real Redis" do
    let(:real_redis) { Redis.new(url: ENV.fetch("DIGEST_PACING_TEST_REDIS_URL"), driver: :ruby) }
    let(:pool) { ConnectionPool.new(size: 1) { real_redis } }
    let(:limiter) { Emails::DigestDeliveryLimiter }
    let(:interval) { limiter::INTERVAL }

    before do
      allow(Sidekiq).to receive(:redis_pool).and_return(pool)
      allow(Emails::DigestDeliveryLimiter).to receive(:call).and_call_original
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

    # Verify one job's complete lifecycle through the real client/server middleware.
    # rubocop:disable RSpec/MultipleExpectations
    it "retains a deferred unique job and delivers it after the slot expires" do
      real_redis.set(limiter::ACTIVE_SLOT_KEY, "1", ex: interval)
      jid = described_class.perform_async(user.id)
      expect(jid).to be_present
      expect(described_class.perform_async(user.id)).to be_nil

      execute_queued_digest

      scheduled = Sidekiq::ScheduledSet.new.to_a
      expect(scheduled.size).to eq(1)
      expect(scheduled.first.args.first).to eq(user.id)
      expect(scheduled.first.args.last).to include("delivery_slot_at" => a_kind_of(Integer))
      expect(described_class.perform_async(user.id)).to be_nil
      expect(described_class.perform_async(user.id, {})).to be_nil
      expect(described_class.perform_async(user.id, "delivery_slot_at" => 1.hour.from_now.to_i)).to be_nil
      expect(delivery).not_to have_received(:deliver_now)

      real_redis.expire(limiter::ACTIVE_SLOT_KEY, 0)
      Timecop.travel(((interval * 2) + 1).seconds.from_now) do
        Sidekiq::Scheduled::Enq.new.enqueue_jobs
        execute_queued_digest
      end

      expect(delivery).to have_received(:deliver_now).once
      expect(Sidekiq::ScheduledSet.new.size).to eq(0)
      expect(described_class.perform_async(user.id, "test_attempt_id" => 111)).to be_present
      expect(described_class.perform_async(user.id, "test_attempt_id" => 222)).to be_present
      expect(described_class.perform_async(user.id, "test_attempt_id" => 111)).to be_nil
    end
    # rubocop:enable RSpec/MultipleExpectations

    it "allocates a different future slot to every eligible digest in a batch" do
      Timecop.freeze do
        expect(limiter.call).to be_nil
        slots = Array.new(5) { limiter.call }

        expect(slots).to eq((1..5).map { |offset| Time.current.to_i + (interval * offset) })
        expect(real_redis.ttl(limiter::NEXT_SLOT_KEY)).to be_between(interval * 5, interval * 6)
        expect(limiter.call(reserved_at: slots.first)).to eq(slots.first)
      end
    end

    it "spaces overdue reservations again after a worker outage" do
      Timecop.freeze do
        expired_reservation = 1.hour.ago.to_i
        expect(limiter.call(reserved_at: expired_reservation)).to be_nil
        slots = Array.new(5) { limiter.call(reserved_at: expired_reservation) }

        expect(slots).to eq((1..5).map { |offset| Time.current.to_i + (interval * offset) })
      end
    end

    it "gives previews timely slots while sharing the actual SMTP delivery guard" do
      Timecop.freeze do
        expect(limiter.call).to be_nil
        bulk_slots = Array.new(5) { limiter.call }
        preview_slot = limiter.call(priority: true)

        expect(preview_slot).to eq(Time.current.to_i + interval)
        expect(preview_slot).to be < bulk_slots.last
        real_redis.expire(limiter::ACTIVE_SLOT_KEY, 0)
        Timecop.travel(Time.zone.at(preview_slot)) do
          expect(limiter.call(reserved_at: preview_slot, priority: true)).to be_nil
          expect(limiter.call(reserved_at: bulk_slots.first)).to be > Time.current.to_i
        end
      end
    end

    it "reserves distinct slots after an SMTP cooldown without claiming a delivery" do
      Timecop.freeze do
        retry_at = 1.hour.from_now.to_i
        expect(limiter.call(not_before: 1.second.ago.to_i)).to eq(Time.current.to_i + interval)
        slots = Array.new(5) { limiter.call(not_before: retry_at) }

        expect(slots).to eq((0..4).map { |offset| retry_at + (interval * offset) })
        expect(real_redis.exists?(limiter::ACTIVE_SLOT_KEY)).to be(false)
        expect(limiter.call(reserved_at: slots.first, not_before: retry_at)).to eq(slots.first)
        expect(limiter.call(reserved_at: 1.minute.from_now.to_i, not_before: retry_at))
          .to eq(retry_at + (interval * 5))
      end
    end

    def execute_queued_digest
      job = Sidekiq.load_json(real_redis.rpop("queue:email_digest"))
      worker = described_class.new
      chain = Sidekiq::Middleware::Chain.new
      chain.add SidekiqUniqueJobs::Middleware::Client
      chain.add SidekiqUniqueJobs::Middleware::Server
      chain.invoke(worker, job, "email_digest") { worker.perform(*job.fetch("args")) }
    end
  end
end
