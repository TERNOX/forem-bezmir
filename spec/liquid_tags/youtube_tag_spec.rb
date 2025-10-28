require "rails_helper"

RSpec.describe YoutubeTag, type: :liquid_tag do
  describe "#id" do
    let(:valid_id) { "vKeCr-MAyH4" }

    def generate_tag(input)
      Liquid::Template.parse("{% embed #{input} %}").render
    end

    def iframe_src(html)
      Nokogiri::HTML.fragment(html).at_css("iframe")&.[]("src")
    end

    def query_params_for(src)
      URI.parse(src).query.to_s.split("&")
    end

    it "accepts a short URL" do
      result = generate_tag("https://youtu.be/#{valid_id}")
      src = iframe_src(result)
      expect(src).to start_with("https://www.youtube.com/embed/#{valid_id}")
      expect(query_params_for(src)).to include("autoplay=1", "rel=0", "modestbranding=1", "playsinline=1")
    end

    it "accepts a short URL with 'si' parameter" do
      result = generate_tag("https://youtu.be/#{valid_id}?si=FPFWKE9g0PhQjAUE")
      src = iframe_src(result)
      expect(src).to start_with("https://www.youtube.com/embed/#{valid_id}")
      expect(query_params_for(src)).to include(a_string_starting_with("origin="))
    end

    it "accepts a short URL with 't' parameter" do
      result = generate_tag("https://youtu.be/#{valid_id}?t=231")
      src = iframe_src(result)
      expect(query_params_for(src)).to include("start=231")
    end

    it "accepts a short URL with both 'si' and 't' parameters" do
      result = generate_tag("https://youtu.be/#{valid_id}?si=FPFWKE9g0PhQjAUE&t=231")
      src = iframe_src(result)
      expect(query_params_for(src)).to include("start=231")
    end

    it "accepts a full URL with 'v' parameter" do
      result = generate_tag("https://www.youtube.com/watch?v=#{valid_id}")
      src = iframe_src(result)
      expect(src).to start_with("https://www.youtube.com/embed/#{valid_id}")
    end

    it "accepts a full URL with 'v' and 't' parameters" do
      result = generate_tag("https://www.youtube.com/watch?v=#{valid_id}&t=231s")
      src = iframe_src(result)
      expect(query_params_for(src)).to include("start=231")
    end

    it "accepts a full URL with 'si' and 'v' parameters in different order" do
      result = generate_tag("https://www.youtube.com/watch?si=FPFWKE9g0PhQjAUE&v=#{valid_id}")
      src = iframe_src(result)
      expect(src).to start_with("https://www.youtube.com/embed/#{valid_id}")
    end

    it "accepts an ID only" do
      result = Liquid::Template.parse("{% youtube #{valid_id} %}").render
      src = iframe_src(result)
      expect(src).to start_with("https://www.youtube.com/embed/#{valid_id}")
    end

    it "raises an error for invalid IDs" do
      expect do
        generate_tag("invalid-id")
      end.to raise_error(StandardError)
    end

    it "raises an error for invalid URLs" do
      stub_request(:any, "https://example.com/not-a-youtube-url").to_return(status: 404)
      expect do
        generate_tag("https://example.com/not-a-youtube-url")
      end.to raise_error(StandardError)
    end
  end
end
