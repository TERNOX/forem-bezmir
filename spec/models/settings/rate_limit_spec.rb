require "rails_helper"

RSpec.describe Settings::RateLimit do
  describe ".user_considered_new?" do
    subject(:function_call) { described_class.user_considered_new?(user: user) }

    before do
      allow(described_class).to receive(:user_considered_new_days).and_return(5)
    end

    context "when given a nil user" do
      let(:user) { nil }

      it { is_expected.to be_truthy }
    end

    context "when given a decorated user that was created months ago" do
      let(:user) { create(:user).decorate }

      before { allow(user).to receive(:created_at).and_return(30.months.ago) }

      it { is_expected.to be_falsey }
    end

    context "when given a decorated user that was created within the user_considered_new_days" do
      let(:user) { create(:user).decorate }

      before { allow(user).to receive(:created_at).and_return(3.days.ago) }

      it { is_expected.to be_truthy }
    end
  end

  describe ".trigger_spam_for?" do
    subject { described_class.trigger_spam_for?(text: text) }

    let(:text) { "text to test" }

    context "when it matches a spam trigger term" do
      before do
        allow(described_class).to receive(:spam_trigger_terms).and_return(["to test"])
      end

      it { is_expected.to be_truthy }
    end

    context "when there are no spam trigger terms" do
      before do
        allow(described_class).to receive(:spam_trigger_terms).and_return([])
      end

      it { is_expected.to be_falsey }
    end

    context "when there are spam trigger terms but they don't match" do
      before do
        allow(described_class).to receive(:spam_trigger_terms).and_return(["in a hole in the ground"])
      end

      it { is_expected.to be_falsey }
    end
  end

  describe ".spam_exempt?" do
    let(:user) { create(:user, username: "trusted_author") }
    let(:organization) { create(:organization, slug: "trusted-org") }

    before do
      allow(described_class).to receive_messages(spam_exempt_usernames: [" @Trusted_Author "],
                                                 spam_exempt_organization_slugs: ["Trusted-Org"])
    end

    it "matches allowlisted usernames ignoring case, spaces and a leading @" do
      expect(described_class.spam_exempt?(user: user)).to be(true)
    end

    it "matches allowlisted organization slugs ignoring case" do
      expect(described_class.spam_exempt?(user: create(:user), organization: organization)).to be(true)
    end

    it "does not match other users or organizations" do
      expect(described_class.spam_exempt?(user: create(:user), organization: create(:organization))).to be(false)
    end

    it "handles a missing user and organization" do
      expect(described_class.spam_exempt?(user: nil)).to be(false)
    end

    it "is false by default" do
      allow(described_class).to receive_messages(spam_exempt_usernames: [], spam_exempt_organization_slugs: [])
      expect(described_class.spam_exempt?(user: user, organization: organization)).to be(false)
    end
  end

  describe ".ai_spam_moderation?" do
    it "is true when a Gemini key is present and the admin toggle is on" do
      stub_const("Ai::Base::DEFAULT_KEY", "present")
      expect(described_class.ai_spam_moderation?).to be(true)
    end

    it "is false when the admin toggle is off" do
      stub_const("Ai::Base::DEFAULT_KEY", "present")
      allow(described_class).to receive(:ai_spam_moderation_enabled).and_return(false)
      expect(described_class.ai_spam_moderation?).to be(false)
    end

    it "is false without a Gemini key" do
      stub_const("Ai::Base::DEFAULT_KEY", nil)
      expect(described_class.ai_spam_moderation?).to be(false)
    end
  end

  describe ".ai_moderation_model_or" do
    it "returns the fallback when no model is configured" do
      expect(described_class.ai_moderation_model_or("fallback-model")).to eq("fallback-model")
    end

    it "returns the configured model" do
      allow(described_class).to receive(:ai_moderation_model).and_return("gemini-2.5-flash")
      expect(described_class.ai_moderation_model_or("fallback-model")).to eq("gemini-2.5-flash")
    end
  end
end
