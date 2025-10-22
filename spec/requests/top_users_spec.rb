require "rails_helper"

RSpec.describe "TopUsers", type: :request do
  describe "GET /top_users" do
    it "returns success and orders users by reputation" do
      highest = create(:user, username: "highest", reputation_score: 250)
      middle = create(:user, username: "middle", reputation_score: 120)
      lower = create(:user, username: "lower", reputation_score: 30)

      get "/top_users"

      expect(response).to have_http_status(:ok)
      body = response.body

      helper = ActionController::Base.helpers

      expect(body).to include(highest.username, middle.username, lower.username)
      expect(body.index(highest.username)).to be < body.index(middle.username)
      expect(body.index(middle.username)).to be < body.index(lower.username)
      expect(body).to include(helper.number_with_delimiter(highest.reputation_score))
    end

    it "limits the list to 50 users" do
      create_list(:user, 55, reputation_score: 10)

      get "/top_users"

      document = Nokogiri::HTML(response.body)
      expect(document.css(".top-users__list > li").count).to eq(50)
    end
  end
end
