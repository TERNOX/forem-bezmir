require "rails_helper"

RSpec.describe Listings::ExpireOldListingsWorker, type: :worker do
  include_examples "#enqueues_on_correct_queue", "low_priority"

  def create_cron_job(name, worker_class: described_class.name, source: nil)
    job = Sidekiq::Cron::Job.new(
      name: name,
      cron: "30 0 * * *",
      class: worker_class,
      queue: "low_priority",
      source: source,
    )
    # Seed legacy Redis records without a source. Single-field HSET also works
    # with the test suite's fakeredis, which predates multi-field HSET support.
    attributes = job.to_hash
    attributes.delete("source") unless source
    redis_key = Sidekiq::Cron::Job.redis_key(name)
    Sidekiq.redis do |redis|
      redis.sadd(Sidekiq::Cron::Job.jobs_key, [redis_key])
      attributes.each { |key, value| redis.hset(redis_key, key, value || "") }
    end
    job
  end

  def cron_job(name)
    Sidekiq::Cron::Job.all.detect { |job| job.name == name }
  end

  it "removes the legacy cron entry that survives schedule synchronization" do
    create_cron_job("expire_old_listings")
    Sidekiq::Cron::Job.destroy_removed_jobs([])
    expect(cron_job("expire_old_listings")).to be_present

    described_class.new.perform

    expect(cron_job("expire_old_listings")).to be_nil
  end

  it "matches the retired class regardless of the cron entry's name or source" do
    create_cron_job("legacy_listings_expiration")
    create_cron_job("scheduled_listings_expiration", source: "schedule")
    create_cron_job("send_digest", worker_class: "Emails::EnqueueDigestWorker")

    described_class.new.perform

    expect(Sidekiq::Cron::Job.all.map(&:name)).to contain_exactly("send_digest")
  end

  it "preserves a replacement worker registered under the old cron name" do
    create_cron_job("expire_old_listings", worker_class: "Emails::EnqueueDigestWorker")

    described_class.new.perform

    expect(cron_job("expire_old_listings").klass).to eq("Emails::EnqueueDigestWorker")
  end

  it "finishes already queued jobs with the original class name and empty arguments" do
    Sidekiq::Testing.fake! do
      Sidekiq::Client.push(
        "class" => "Listings::ExpireOldListingsWorker",
        "queue" => "low_priority",
        "args" => [],
        "retry" => 5,
        "retry_count" => 4,
      )

      expect { described_class.drain }.not_to raise_error
      expect(described_class.jobs).to be_empty
    end
  end

  it "can run repeatedly after the obsolete schedule has been removed" do
    create_cron_job("expire_old_listings")
    described_class.new.perform

    expect { described_class.new.perform }.not_to raise_error
    expect(cron_job("expire_old_listings")).to be_nil
  end
end
