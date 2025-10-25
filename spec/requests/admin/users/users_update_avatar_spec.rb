require "rails_helper"

RSpec.describe "/admin/member_manager/users" do
  let!(:user) { create(:user) }
  let!(:admin) { create(:user, :super_admin) }

  before do
    sign_in(admin)
  end

  describe "PATCH /admin/member_manager/users/:id/update_avatar" do
    let(:new_avatar_url) { "https://example.com/avatar.png" }

    before do
      allow(Images::SafeRemoteProfileImageUrl).to receive(:call).and_call_original
    end

    it "updates the user's avatar" do
      allow_any_instance_of(User).to receive(:remote_profile_image_url=) do |instance, url|
        expect(url).to eq(new_avatar_url)
        instance.profile_image = Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/800x600.png"),
          "image/png",
        )
      end

      expect do
        patch update_avatar_admin_user_path(user.id), params: {
          user: {
            remote_profile_image_url: new_avatar_url
          }
        }
      end.to change(Note, :count).by(1)

      user.reload
      expect(user.profile_image?).to be(true)
      expect(Images::SafeRemoteProfileImageUrl).to have_received(:call).with(new_avatar_url)
      note = Note.last
      expect(note.reason).to eq("Update Avatar")
      expect(note.content).to include(new_avatar_url)
      expect(note.author_id).to eq(admin.id)
      expect(note.noteable_id).to eq(user.id)
      expect(flash[:success]).to eq(I18n.t("views.admin.users.update_avatar.success"))
      expect(response).to redirect_to(admin_user_path(user))
    end

    it "removes the user's avatar when no URL is provided" do
      expect(user.profile_image?).to be(true)

      expect do
        patch update_avatar_admin_user_path(user.id), params: {
          user: {
            remote_profile_image_url: ""
          }
        }
      end.to change(Note, :count).by(1)

      user.reload
      expect(user.profile_image?).to be(false)
      note = Note.last
      expect(note.reason).to eq("Update Avatar")
      expect(note.content).to eq("Removed user's avatar.")
      expect(flash[:success]).to eq(I18n.t("views.admin.users.update_avatar.removed"))
      expect(response).to redirect_to(admin_user_path(user))
    end
  end
end
