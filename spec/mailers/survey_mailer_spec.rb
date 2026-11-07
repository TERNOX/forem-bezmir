require "rails_helper"

RSpec.describe SurveyMailer, type: :mailer do
  describe "pulse_survey" do
    let(:user) { create(:user) }
    let(:survey) { create(:survey, title: "Standard Survey", extra_email_context_paragraph: "This is a super important survey.") }
    let(:mail) { SurveyMailer.with(user: user, survey: survey).pulse_survey }
    let(:community_name) { Settings::Community.community_name }

    context "when survey is community_pulse (default)" do
      it "renders the headers" do
        expect(mail.subject).to eq("You've been randomly selected for a #{community_name} Pulse Survey")
        expect(mail.to).to eq([user.email])
      end

      it "renders the body with link to survey" do
        expect(mail.body.encoded).to include(user.name)
        expect(mail.body.encoded).to include(survey.slug)
        expect(mail.body.encoded).to include("Take the #{community_name} Pulse Survey")
        expect(mail.body.encoded).to include("This is a super important survey.")
        expect(mail.body.encoded).to include("randomly selected to participate in a #{community_name} Pulse Survey.")
      end
    end

    context "when survey is industry" do
      let(:survey) { create(:survey, title: "Industry Survey", type_of: :industry, extra_email_context_paragraph: "Industry details.") }

      it "renders the headers" do
        expect(mail.subject).to eq("You've been randomly selected for a very quick #{community_name} Industry Survey")
      end

      it "renders the body with link to survey" do
        expect(mail.body.encoded).to include("Take the #{community_name} Industry Survey")
        expect(mail.body.encoded).to include("Industry details.")
        expect(mail.body.encoded).to include("invite you to participate in a #{community_name} Industry Survey.")
      end
    end

    context "when survey is fun" do
      let(:survey) { create(:survey, title: "Fun Survey", type_of: :fun, extra_email_context_paragraph: "Fun details.") }

      it "renders the headers" do
        expect(mail.subject).to eq("A quick, fun survey from #{community_name}!")
      end

      it "renders the body with link to survey" do
        expect(mail.body.encoded).to include("Take this quick #{community_name} Survey")
        expect(mail.body.encoded).to include("Fun details.")
        expect(mail.body.encoded).to include("invite you to participate in a quick, fun survey from #{community_name}.")
      end
    end

    context "when survey is beta_testing" do
      let(:survey) do
        create(:survey, title: "Beta Survey", type_of: :beta_testing, extra_email_context_paragraph: "Beta details.")
      end

      it "renders the headers" do
        expect(mail.subject).to eq("You've been randomly selected for a beta testing survey")
      end

      it "renders the body with link to survey" do
        expect(mail.body.encoded).to include("Take the Beta Testing Survey")
        expect(mail.body.encoded).to include("Beta details.")
        expect(mail.body.encoded).to include("randomly selected to participate in a beta testing survey.")
      end
    end

    context "when survey has HTML in extra_email_context_paragraph" do
      let(:survey) do
        create(:survey,
               title: "HTML Survey",
               extra_email_context_paragraph: '<p><a href="https://dev.to" target="_blank">our announcement</a> and ' \
                                              "<strong>details</strong>.</p>")
      end

      it "renders unescaped safe HTML in the email body" do
        expect(mail.body.encoded).to include('target="_blank">our announcement</a>')
        expect(mail.body.encoded).to include("<strong>details</strong>")
      end

      it "sanitizes unsafe HTML tags and handlers" do
        survey.update!(
          extra_email_context_paragraph: 'Safe <script>alert(1)</script><a href="https://dev.to" onclick="h()">link</a>',
        )
        expect(mail.body.encoded).not_to include("<script>")
        expect(mail.body.encoded).not_to include("onclick")
        expect(mail.body.encoded).to include(">link</a>")
        expect(mail.body.encoded).to include("https%3A%2F%2Fdev.to")
      end
    end
  end
end
