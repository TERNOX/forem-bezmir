require "rails_helper"

RSpec.describe "VideoUploads" do
  describe "POST /video_uploads" do
    let(:user) { create(:user) }
    let(:headers) { { "Content-Type": "application/json", Accept: "application/json" } }
    let(:tempfile) do
      file = Tempfile.new(["video", ".mp4"])
      file.binmode
      file.write("stub")
      file.rewind
      file
    end
    let(:video) { Rack::Test::UploadedFile.new(tempfile.path, "video/mp4") }
    let(:uploader) { instance_double(VideoUploader, store!: true, url: "https://example.com/video.mp4") }

    before do
      allow(VideoUploader).to receive(:new).and_return(uploader)
    end

    after do
      tempfile.close
      tempfile.unlink
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        post "/video_uploads", headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated" do
      before do
        sign_in user
      end

      it "returns the uploaded video url" do
        post "/video_uploads", headers: headers, params: { video: video }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["links"]).to eq(["https://example.com/video.mp4"])
        expect(response.parsed_body["kind"]).to eq("video")
        expect(response.parsed_body["markdown"]).to eq("![](https://example.com/video.mp4)")
      end

      it "accepts quicktime files" do
        quicktime = Rack::Test::UploadedFile.new(tempfile.path, "video/quicktime")

        post "/video_uploads", headers: headers, params: { video: quicktime }

        expect(response).to have_http_status(:ok)
      end

      it "rejects unsupported mime types" do
        invalid = Rack::Test::UploadedFile.new(tempfile.path, "application/octet-stream")

        post "/video_uploads", headers: headers, params: { video: invalid }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to eq(I18n.t("video_uploads_controller.invalid_format"))
      end

      it "rejects files larger than allowed" do
        allow(Settings::General).to receive(:video_upload_max_file_size_mb).and_return(1)
        allow(video).to receive(:size).and_return(3.megabytes)

        post "/video_uploads", headers: headers, params: { video: video }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to include("1")
      end

      it "prevents filenames that are too long" do
        allow(video).to receive(:original_filename).and_return("#{'a' * 260}.mp4")

        post "/video_uploads", headers: headers, params: { video: video }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "limits upload rate" do
        allow(Rails.cache).to receive(:increment)
        allow(Rails.cache).to receive(:read).and_return(Settings::RateLimit.video_upload + 1)

        post "/video_uploads", headers: headers, params: { video: video }

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end
end
