require "rails_helper"

RSpec.describe "TopUsers", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET /top_users" do
    it "returns success, sets the page title, and orders users by reputation" do
      highest = create(:user, username: "highest", reputation_score: 250)
      middle = create(:user, username: "middle", reputation_score: 120)
      lower = create(:user, username: "lower", reputation_score: 30)

      get "/top_users"

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)

      expect(document.at_css("title").text).to eq(I18n.t("views.top_users.title"))

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

    it "shows available monthly tabs and renders selected month" do
      period = Date.new(2025, 10, 1)
      monthly_user = create(:user, username: "monthly-star")
      create(:monthly_user_reputation, user: monthly_user, period: period, score: 42, rank: 1)

      get "/top_users", params: { period: "2025-10" }

      expect(response.body).to include(I18n.l(period, format: :long_month))
      expect(response.body).to include(monthly_user.username)
      expect(response.body).to include(I18n.t("views.top_users.reputation_label_month", month: I18n.l(period, format: :long_month)))
    end

    it "lists the current month tab even before data exists" do
      travel_to(Time.zone.local(2025, 10, 10, 12, 0, 0)) do
        get "/top_users"

        current_label = I18n.l(Date.new(2025, 10, 1), format: :long_month)
        expect(response.body).to include(current_label)
      end
    end

    it "refreshes the current month leaderboard after new likes" do
      travel_to(Time.zone.local(2025, 10, 15, 12, 0, 0)) do
        period_param = Time.zone.today.strftime("%Y-%m")
        tracked_period = Time.zone.today.beginning_of_month.to_date
        score_selector = ".top-users__score .fs-xl.fw-bold.color-base-90"

        top_user = create(:user, username: "refresh-me")
        article = create(:article, user: top_user)

        liker_one = create(:user)
        create(:reaction, user: liker_one, reactable: article, category: "like", created_at: Time.current)

        get "/top_users", params: { period: period_param }
        expect(response).to have_http_status(:ok)

        initial_document = Nokogiri::HTML(response.body)
        initial_score = initial_document.at_css(score_selector)&.text&.strip
        expect(initial_score).to eq("1")
        expect(MonthlyUserReputation.for_period(tracked_period).pluck(:score)).to eq([1])

        liker_two = create(:user)
        create(:reaction, user: liker_two, reactable: article, category: "like", created_at: Time.current + 1.hour)

        get "/top_users", params: { period: period_param }
        expect(response).to have_http_status(:ok)

        updated_document = Nokogiri::HTML(response.body)
        updated_score = updated_document.at_css(score_selector)&.text&.strip
        expect(updated_score).to eq("2")
        expect(MonthlyUserReputation.for_period(tracked_period).pluck(:score)).to eq([2])
      end
    end
  end
end
