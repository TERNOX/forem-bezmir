require "rails_helper"

RSpec.describe VotingTag, type: :liquid_tag do
  let!(:voting) { create(:voting, slug: "gra-roku-2026", title: "Гра року 2026") }

  def render_tag(markup)
    Liquid::Template.parse("{% voting #{markup} %}").render
  end

  it "renders a card from a slug or a /vote/ URL" do
    create(:voting_category, voting: voting)
    expect(render_tag("gra-roku-2026")).to include("Гра року 2026").and include("/vote/gra-roku-2026")
    expect(render_tag("https://example.com/vote/gra-roku-2026")).to include("ltag__voting")
  end

  it "raises for unknown or unpublished votings" do
    voting.update!(published: false)
    expect { render_tag("gra-roku-2026") }.to raise_error(StandardError)
  end
end
