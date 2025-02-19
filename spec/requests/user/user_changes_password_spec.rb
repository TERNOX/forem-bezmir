require "rails_helper"

RSpec.describe "User changes password" do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password, password_confirmation: password) }

  describe "POST /users/update_password" do
    it "does not update the password if the current password is wrong" do
      sign_in user
      post user_update_password_path,
           params: {
             current_password: "wrongwrong",
             password: "testtest",
             password_confirmation: "testtest"
           }

      expect(response.body).to include("Поточний пароль недійсний")
    end

    it "does not update the password if the new password is too short" do
      sign_in user
      post user_update_password_path,
           params: {
             current_password: password,
             password: "test",
             password_confirmation: "test"
           }

      expect(response.body).to include("Пароль дуже короткий (мінімум 8 символів)")
    end

    it "does not update the password if the new passwords don't match" do
      sign_in user
      post user_update_password_path,
           params: {
             current_password: password,
             password: "testtest",
             password_confirmation: "testtesy"
           }

      expect(response.body).to include("error")
      expected_message = CGI.escapeHTML("Пароль не збігається з підтвердженням пароля")
      expect(response.body).to include(expected_message)
    end

    it "updates the password if all params are valid" do
      sign_in user
      post user_update_password_path,
           params: {
             current_password: password,
             password: "testtest",
             password_confirmation: "testtest"
           }

      expect(response.body).not_to include("error")
      expect(response).to redirect_to("/settings/account")
    end
  end
end
