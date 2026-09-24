require "rails_helper"

RSpec.describe "shared/_billboard" do
  let(:billboard) { create(:billboard, placement_area: "post_body_bottom", color: "#aabbcc") }

  def render_billboard
    render partial: "shared/billboard", locals: { billboard: billboard, data_context_type: "article" }
    Nokogiri::HTML.fragment(rendered).at_css("[data-display-unit]")
  end

  %w[plain authorship_box].each do |template|
    context "with the #{template} template" do
      before { billboard.update!(template: template) }

      it "separates a below-body billboard from the article text" do
        expect(render_billboard["class"].split).to include("mt-6")
      end

      it "omits the colored border when disabled" do
        billboard.update!(show_border: false)
        expect(render_billboard["style"]).to eq("")
      end

      it "renders the selected border when enabled" do
        expect(render_billboard["style"]).to eq("border: 1px solid #aabbcc;")
      end
    end
  end

  it "does not add spacing to plain billboards in other placements" do
    billboard.update!(template: "plain", placement_area: "sidebar_left")
    expect(render_billboard["class"].split).not_to include("mt-6")
  end
end
