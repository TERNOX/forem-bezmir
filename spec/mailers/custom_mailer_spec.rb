require "rails_helper"

RSpec.describe CustomMailer, type: :mailer do
  describe "#custom_email" do
    let(:user) { create(:user) }
    let(:content) { "Hello *|name|*, this is a test email." }
    let(:subject) { "Test Email Subject for *|name|*" }
    let(:unsubscribe_token) { "unsubscribe_token" }
    let(:mail) { described_class.with(user: user, content: content, subject: subject).custom_email }

    before do
      allow_any_instance_of(CustomMailer).to receive(:generate_unsubscribe_token).and_return(unsubscribe_token)
    end

    context "when SendGrid is enabled" do
      before do
        allow(ForemInstance).to receive(:sendgrid_enabled?).and_return(true)
      end

      it "sets the X-SMTPAPI header with the correct category" do
        mail.deliver_now
        expect(mail.header["X-SMTPAPI"]).not_to be_nil
        smtpapi_header = JSON.parse(mail.header["X-SMTPAPI"].value)
        expect(smtpapi_header).to have_key("category")
        expect(smtpapi_header["category"]).to include("Custom Email")
      end

      it "replaces the *|name|* merge tag in content and subject" do
        allow_any_instance_of(CustomMailer).to receive(:email_from).and_return("no-reply@example.com")
        expected_content = "Hello #{user.name}, this is a test email."
        expected_subject = "Test Email Subject for #{user.name}"

        expect(mail.to).to eq([user.email])
        expect(mail.subject).to eq(expected_subject)
        expect(mail.from).to eq(["no-reply@example.com"])
        expect(mail.body.encoded).to include(expected_content)
        expect(mail.body.encoded).to include(unsubscribe_token)
      end
    end

    context "when there is an email passed" do
      let(:email) { create(:email, type_of: "onboarding_drip") }
      let(:second_user) { create(:user) }

      before do
        allow(ForemInstance).to receive(:smtp_enabled?).and_return(true)
        # This will allow us to test the actual 'from' logic that uses the email_id
        allow(ForemInstance).to receive(:from_email_address).and_return("no-reply@community.com")
        allow(Settings::Community).to receive(:community_name).and_return("MyCommunity")
      end

      it "tracks the email_id after delivery" do
        described_class.with(user: second_user, content: content, subject: subject, email_id: email.id).custom_email.deliver_now
        expect(email.reload.email_messages.count).to eq(1)
      end

      it "includes the from topic in the from address based on the email type when onboarding" do
        described_class.with(user: second_user, content: content, subject: subject, email_id: email.id).custom_email.deliver_now
        delivered_mail = ActionMailer::Base.deliveries.last

        # For onboarding_drip, the default_from_name_based_on_type should return "Onboarding"
        expected_from_name = "MyCommunity Onboarding"
        expected_from = "#{expected_from_name} <no-reply@community.com>"
        
        expect(delivered_mail[:from].value).to eq(expected_from)
      end

      it "includes the from topic in the from address based on the email type when newsletter" do
        email.update_column(:type_of, "newsletter")
        described_class.with(user: second_user, content: content, subject: subject, email_id: email.id).custom_email.deliver_now
        delivered_mail = ActionMailer::Base.deliveries.last

        # For newsletter, the default_from_name_based_on_type should return "Newsletter"
        expected_from_name = "MyCommunity Newsletter"
        expected_from = "#{expected_from_name} <no-reply@community.com>"
      
        expect(delivered_mail[:from].value).to eq(expected_from)
      end

      it "includes the from topic in the from address based on the email type when one_off" do
        email.update_column(:type_of, "one_off")
        described_class.with(user: second_user, content: content, subject: subject, email_id: email.id).custom_email.deliver_now
        delivered_mail = ActionMailer::Base.deliveries.last

        # For one_off, the default_from_name_based_on_type should return an empty string
        expected_from_name = "MyCommunity"
        expected_from = "#{expected_from_name} <no-reply@community.com>"

        expect(delivered_mail[:from].value).to eq(expected_from)
      end
    end

    context "when from_name param is passed" do
      let(:email) { create(:email, type_of: "newsletter") }

      before do
        allow(ForemInstance).to receive(:smtp_enabled?).and_return(true)
        allow(ForemInstance).to receive(:from_email_address).and_return("no-reply@community.com")
        allow(Settings::Community).to receive(:community_name).and_return("MyCommunity")
      end

      it "uses the from_name param instead of querying the Email record" do
        expect(Email).not_to receive(:find_by)

        described_class.with(
          user: user, content: content, subject: subject,
          email_id: email.id, from_name: "Newsletter",
        ).custom_email.deliver_now

        delivered_mail = ActionMailer::Base.deliveries.last
        expect(delivered_mail[:from].value).to eq("MyCommunity Newsletter <no-reply@community.com>")
      end

      it "falls back to Email lookup when from_name is nil" do
        described_class.with(
          user: user, content: content, subject: subject,
          email_id: email.id, from_name: nil,
        ).custom_email.deliver_now

        delivered_mail = ActionMailer::Base.deliveries.last
        # Should still resolve from the Email record
        expect(delivered_mail[:from].value).to eq("MyCommunity Newsletter <no-reply@community.com>")
      end

      it "falls back to Email lookup when from_name is not provided" do
        described_class.with(
          user: user, content: content, subject: subject,
          email_id: email.id,
        ).custom_email.deliver_now

        delivered_mail = ActionMailer::Base.deliveries.last
        expect(delivered_mail[:from].value).to eq("MyCommunity Newsletter <no-reply@community.com>")
      end
    end

    context "with one-click unsubscribe" do
      let(:email) { mail }

      include_examples "#renders_one_click_unsubscribe_headers"
    end

    context "when SendGrid is disabled" do
      before do
        allow(ForemInstance).to receive(:sendgrid_enabled?).and_return(false)
      end

      it "does not set the X-SMTPAPI header" do
        expect(mail.headers["X-SMTPAPI"]).to be_nil
      end

      it "replaces the *|name|* merge tag in content and subject" do
        allow_any_instance_of(CustomMailer).to receive(:email_from).and_return("no-reply@example.com")
        expected_content = "Hello #{user.name}, this is a test email."
        expected_subject = "Test Email Subject for #{user.name}"

        expect(mail.to).to eq([user.email])
        expect(mail.subject).to eq(expected_subject)
        expect(mail.from).to eq(["no-reply@example.com"])
        expect(mail.body.encoded).to include(expected_content)
        expect(mail.body.encoded).to include(unsubscribe_token)
      end
    end

    context "when footer override functionality is used" do
      let(:app_wide_footer) { "<p>This is the app-wide footer</p>" }

      before do
        allow(Settings::General).to receive(:custom_email_footer).and_return(app_wide_footer)
      end

      it "renders the app-wide footer when override is not enabled" do
        email = create(:email, override_footer_html: false, custom_footer_html: "<p>Custom footer</p>")
        mailer = described_class.with(user: user, content: content, subject: subject, email_id: email.id).custom_email

        expect(mailer.body.encoded).to include(app_wide_footer)
        expect(mailer.body.encoded).not_to include("Custom footer")
      end

      it "renders the custom footer and replaces merge tags when override is enabled" do
        custom_footer = "<p>Special footer for *|name|* (*|email|*)</p>"
        email = create(:email, override_footer_html: true, custom_footer_html: custom_footer)
        mailer = described_class.with(user: user, content: content, subject: subject, email_id: email.id).custom_email

        expect(mailer.body.encoded).not_to include(app_wide_footer)
        expect(mailer.body.encoded).to include("Special footer for #{user.name} (#{user.email})")
      end

      it "suppresses footer completely when override is enabled with blank custom footer" do
        email = create(:email, override_footer_html: true, custom_footer_html: "")
        mailer = described_class.with(user: user, content: content, subject: subject, email_id: email.id).custom_email

        expect(mailer.body.encoded).not_to include(app_wide_footer)
      end

      it "respects footer override parameters passed directly via .with" do
        mailer = described_class.with(
          user: user,
          content: content,
          subject: subject,
          override_footer_html: true,
          custom_email_footer: "<p>Param-based footer for *|name|*</p>",
        ).custom_email

        expect(mailer.body.encoded).not_to include(app_wide_footer)
        expect(mailer.body.encoded).to include("Param-based footer for #{user.name}")
      end

      it "sanitizes disallowed HTML markup like iframes in the custom footer" do
        mailer = described_class.with(
          user: user,
          content: content,
          subject: subject,
          override_footer_html: true,
          custom_email_footer: '<p>Safe footer</p><iframe src="https://evil.example"></iframe>',
        ).custom_email

        expect(mailer.body.encoded).to include("<p>Safe footer</p>")
        expect(mailer.body.encoded).not_to include("<iframe")
      end
    end
  end
end
