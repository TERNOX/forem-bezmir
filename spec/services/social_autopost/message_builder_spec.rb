require "rails_helper"

RSpec.describe SocialAutopost::MessageBuilder do
  let(:user) { create(:user, name: "Дарк Валерійович") }
  let(:article) { create(:article, user: user, title: "Огляд Metal Gear Solid V") }

  before { Settings::UserExperience.default_locale = "uk" }

  it "renders the community default like the hand-made posts" do
    text = described_class.new(article, kind: "community").call

    expect(text).to eq(
      "Огляд Metal Gear Solid V\nДопис від нашого користувача Дарк Валерійович\n#{URL.url("/s/#{article.id}")}",
    )
  end

  it "has no community line for staff posts" do
    text = described_class.new(article, kind: "staff").call
    expect(text).not_to include("Допис від")
    expect(text).to include(article.title)
  end

  it "uses a saved template and collapses runs of blank lines" do
    Settings::SocialAutopost.template_digest = "Дописи тижня!\n\n\n\n{{title}} {{username}}\n{{url}}"
    text = described_class.new(article, kind: "digest").call

    expect(text).to eq(
      "Дописи тижня!\n\n#{article.title} #{user.username}\n#{URL.article(article, user_signed_in: false)}",
    )
  end

  it "has defaults in every supported locale" do
    kinds = %w[community staff digest]
    %w[uk en fr pt].each do |locale|
      Settings::UserExperience.default_locale = locale
      kinds.each do |kind|
        expect(described_class.default_template(kind)).to include("{{short_url}}"), "#{locale}.#{kind}"
      end
    end
  end
end
