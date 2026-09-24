require "rails_helper"

RSpec.describe Billboard do
  describe "colored border" do
    let(:billboard) { create(:billboard, color: "#aabbcc", placement_area: "post_body_bottom") }

    it "preserves the existing border by default" do
      expect(billboard.reload).to be_show_border
      expect(billboard.style_string).to eq("border: 1px solid #aabbcc;")
    end

    it "can hide and restore the border without losing its color" do
      billboard.update!(show_border: false)
      expect(billboard.reload.style_string).to eq("")
      expect(billboard.color).to eq("#aabbcc")

      billboard.update!(show_border: true)
      expect(billboard.reload.style_string).to eq("border: 1px solid #aabbcc;")
    end

    it "keeps an uncolored billboard borderless" do
      billboard.update!(color: nil)
      expect(billboard.style_string).to eq("")
    end

    it "respects the toggle for fixed placements" do
      billboard.update!(placement_area: "post_fixed_bottom")
      expect(billboard.style_string).to eq("border: 1px solid #aabbcc; border-bottom: none; border-top-width: 3px;")

      billboard.update!(show_border: false)
      expect(billboard.style_string).to eq("")
    end

    it "updates the content timestamp when the border is toggled" do
      original_time = billboard.content_updated_at
      Timecop.travel(1.minute.from_now) do
        billboard.update!(show_border: false)
        expect(billboard.content_updated_at).to be > original_time
      end
    end

    it "purges the home page when an active billboard border is toggled" do
      billboard.update!(placement_area: "feed_first", approved: true, published: true)
      allow(EdgeCache::PurgeByKey).to receive(:call)

      billboard.update!(show_border: false)

      expect(EdgeCache::PurgeByKey).to have_received(:call).with("main_app_home_page", fallback_paths: "/")
    end
  end
end
