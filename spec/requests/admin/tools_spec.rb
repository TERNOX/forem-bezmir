require "rails_helper"

RSpec.describe "/admin/advanced/tools" do
  context "when the user is not an admin" do
    let(:user) { create(:user) }

    before do
      sign_in user
    end

    it "blocks the request" do
      expect do
        get admin_tools_path
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  context "when the user is a super admin" do
    let(:super_admin) { create(:user, :super_admin) }

    before do
      sign_in super_admin
      get admin_tools_path
    end

    it "allows the request" do
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the user is a single resource admin" do
    let(:single_resource_admin) { create(:user, :single_resource_admin, resource: Tool) }

    before do
      sign_in single_resource_admin
      get admin_tools_path
    end

    it "allows the request" do
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the user is the wrong single resource admin" do
    let(:single_resource_admin) { create(:user, :single_resource_admin, resource: Article) }

    before do
      sign_in single_resource_admin
    end

    it "blocks the request" do
      expect do
        get admin_tools_path
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "POST /admin/advanced/tools/resave_published_articles" do
    let(:super_admin) { create(:user, :super_admin) }

    before do
      sign_in super_admin
    end

    it "enqueues a job to resave published articles" do
      allow(Articles::ResavePublishedWorker).to receive(:perform_async)

      post resave_published_articles_admin_tools_path

      expect(response).to redirect_to(admin_tools_path)
      expect(Articles::ResavePublishedWorker).to have_received(:perform_async)
      expect(flash[:success]).to eq(I18n.t("admin.tools_controller.resave_published_articles.enqueued"))
    end
  end

  describe "top articles digest actions" do
    let(:super_admin) { create(:user, :super_admin) }
    let(:api_secret) { create(:api_secret) }
    let!(:badge) { create(:badge, slug: "top-7") }
    let!(:article) { create(:article, created_at: 3.days.ago) }

    before do
      Settings::General.set_top_articles_digest_bot_api_key(api_secret.secret)
      Settings::General.set_top_articles_digest_title_template("Digest")
      Settings::General.set_top_articles_digest_frequency("weekly")
      Settings::General.set_top_articles_digest_article_limit(5)
      Settings::General.set_top_articles_digest_tags("digest")

      create(:reaction, reactable: article, category: "like", created_at: 2.days.ago)

      sign_in super_admin
    end

    it "publishes a test digest" do
      expect do
        post top_articles_digest_test_publish_admin_tools_path, params: { digest_preview_mode: "settings" }
      end.to change(Article, :count).by(1)

      expect(flash[:success]).to be_present
    end

    it "awards badges to previewed authors" do
      expect do
        post top_articles_digest_test_badges_admin_tools_path, params: { digest_preview_mode: "settings" }
      end.to change(BadgeAchievement, :count).by(1)

      expect(flash[:success]).to be_present
    end
  end

  describe "POST /admin/advanced/tools/monthly_top_users_awards" do
    let(:super_admin) { create(:user, :super_admin) }

    before do
      sign_in super_admin
    end

    it "updates the monthly top users settings" do
      post monthly_top_users_awards_admin_tools_path, params: {
        monthly_top_users: {
          badge_slug: "custom-badge",
          award_day: 3,
          award_time: "05:30",
          message_template: "Congrats %{period}",
        },
      }

      expect(response).to redirect_to(admin_tools_path)
      expect(flash[:success]).to eq(I18n.t("views.admin.tools.monthly_top_users.save_success"))
      expect(Settings::General.monthly_top_users_badge_slug).to eq("custom-badge")
      expect(Settings::General.monthly_top_users_award_day).to eq(3)
      expect(Settings::General.monthly_top_users_award_time).to eq("05:30")
      expect(Settings::General.monthly_top_users_message_template).to eq("Congrats %{period}")
    end

    it "rejects an invalid day" do
      post monthly_top_users_awards_admin_tools_path, params: {
        monthly_top_users: {
          badge_slug: "custom-badge",
          award_day: 0,
          award_time: "05:30",
          message_template: "Congrats %{period}",
        },
      }

      expect(response).to redirect_to(admin_tools_path)
      expect(flash[:danger]).to eq(I18n.t("views.admin.tools.monthly_top_users.errors.invalid_day"))
    end
  end

  describe "POST /admin/advanced/tools" do
    let(:super_admin) { create(:user, :super_admin) }
    let(:next_run_at) { Time.zone.local(2024, 6, 18, 10, 0, 0) }
    before do
      sign_in super_admin
      Settings::General.set_top_articles_digest_next_run_at(nil)
    end

    it "updates digest configuration and refreshes the next run" do
      schedule = instance_double(Articles::TopArticles::DigestSchedule, next_run_at: next_run_at)
      allow(Articles::TopArticles::DigestSchedule).to receive(:new).and_return(schedule)

      travel_to(Time.zone.local(2024, 6, 17, 8, 0, 0)) do
        post admin_tools_path, params: {
          top_articles_digest: {
            bot_api_key: "secret",
            title_template: "Digest",
            tags: "digest",
            image_url: "",
            organization_id: "",
            intro_markdown: "",
            frequency: "weekly",
            article_limit: "5",
            minimum_score: "10",
            badge_slug: "top-7",
            excluded_organization_ids: "",
            excluded_tags: "news, videos",
          },
        }
      end

      expect(Settings::General.top_articles_digest_bot_api_key).to eq("secret")
      expect(Settings::General.top_articles_digest_next_run_at).to eq(next_run_at)
      expect(Settings::General.top_articles_digest_minimum_score).to eq(10)
      expect(Settings::General.top_articles_digest_excluded_tags).to match_array(%w[news videos])
    end

    it "overrides the next run when an hour is selected" do
      expected = nil

      expect(Articles::TopArticles::DigestSchedule).not_to receive(:new)

      travel_to(Time.zone.local(2024, 6, 17, 8, 0, 0)) do
        post admin_tools_path, params: {
          top_articles_digest: {
            bot_api_key: "secret",
            title_template: "Digest",
            tags: "digest",
            image_url: "",
            organization_id: "",
            intro_markdown: "",
            frequency: "weekly",
            article_limit: "5",
            minimum_score: "0",
            badge_slug: "top-7",
            excluded_organization_ids: "",
            excluded_tags: "",
            next_run_hour: "16",
          },
        }

        schedule_zone = Articles::TopArticles::DigestSchedule.time_zone
        expected = schedule_zone.local(2024, 6, 17, 16, 0, 0).in_time_zone(Time.zone)
      end

      expect(Settings::General.top_articles_digest_next_run_at).to eq(expected)
    end

    it "rejects an invalid hour selection" do
      expect(Articles::TopArticles::DigestSchedule).not_to receive(:new)

      travel_to(Time.zone.local(2024, 6, 17, 8, 0, 0)) do
        post admin_tools_path, params: {
          top_articles_digest: {
            bot_api_key: "secret",
            title_template: "Digest",
            tags: "digest",
            image_url: "",
            organization_id: "",
            intro_markdown: "",
            frequency: "weekly",
            article_limit: "5",
            minimum_score: "0",
            badge_slug: "top-7",
            excluded_organization_ids: "",
            excluded_tags: "",
            next_run_hour: "invalid",
          },
        }
      end

      expect(response).to redirect_to(admin_tools_path)
      expect(flash[:danger]).to eq(I18n.t("admin.tools_controller.invalid_next_run_hour"))
      expect(Settings::General.top_articles_digest_next_run_at).to be_nil
    end
  end
end
