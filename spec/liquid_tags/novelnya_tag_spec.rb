require "rails_helper"

RSpec.describe NovelnyaTag, type: :liquid_tag do
  let(:card_url) { "https://novelnya.com/embed/kutok/projects/misto-sniv" }
  let(:card) do
    {
      title: "Місто снів", url: "https://novelnya.com/projects/misto-sniv",
      cover_url: "https://cdn.novelnya.com/cover.webp", developer: "Студія Сон", year: 2026,
      excerpt: "Візуальна новела про сни.", tags: %w[романтика детектив]
    }
  end

  def render(markup)
    Liquid::Template.parse(markup).render
  end

  def stub_card(body, status: 200)
    stub_request(:get, card_url)
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "renders a game card from Новельня for the tag and for a pasted link" do
    stub_card(card)

    rendered = [render("{% novelnya misto-sniv %}"), render("{% embed https://novelnya.com/projects/misto-sniv %}")]

    expect(rendered).to all(include("Місто снів", "Студія Сон, 2026", "Візуальна новела про сни.",
                                    "романтика · детектив"))
    expect(rendered).to all(include('href="https://novelnya.com/projects/misto-sniv"',
                                    'src="https://cdn.novelnya.com/cover.webp"',
                                    I18n.t("liquid_tags.novelnya_tag.open")))
  end

  it "falls back to a plain link when Новельня has no card (18+, hidden, missing)" do
    stub_card({ error: "not found" }, status: 404)

    html = render("{% novelnya misto-sniv %}")

    expect(html).to include('href="https://novelnya.com/projects/misto-sniv"',
                            I18n.t("liquid_tags.novelnya_tag.fallback"))
    expect(html).not_to include("c-embed__cover")
  end

  it "falls back to a plain link when Новельня is down" do
    stub_request(:get, card_url).to_timeout

    expect(render("{% novelnya misto-sniv %}")).to include(I18n.t("liquid_tags.novelnya_tag.fallback"))
  end

  it "ignores links in the card that do not point at Новельня" do
    evil = card.merge(url: "https://evil.example/phish", cover_url: "javascript:alert(1)")
    stub_card(evil)

    html = render("{% novelnya misto-sniv %}")

    expect(html).not_to include("evil.example", "javascript:")
    expect(html).to include('href="https://novelnya.com/projects/misto-sniv"')
  end

  it "rejects input that is not a Новельня game" do
    expect { render("{% novelnya https://example.com/projects/x %}") }
      .to raise_error(StandardError, I18n.t("liquid_tags.novelnya_tag.invalid_url"))
  end
end
