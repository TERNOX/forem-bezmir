FactoryBot.define do
  factory :broadcast do
    active { true }
    active_status_updated_at { 2.days.ago }

    factory :set_up_profile_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "set_up_profile") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.set_up_profile") }
    end

    factory :welcome_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "welcome_thread") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.welcome_thread") }
    end

    factory :apple_connect_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "apple_connect") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.connect.apple") }
    end

    factory :github_connect_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "github_connect") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.connect.github") }
    end

    factory :google_oauth2_connect_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "google_oauth2_connect") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.connect.google") }
    end

    factory :facebook_connect_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "facebook_connect") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.connect.facebook") }
    end

    factory :forem_connect_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "forem_connect") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.connect.forem") }
    end

    factory :twitter_connect_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "twitter_connect") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.connect.twitter") }
    end

    factory :mlh_connect_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "mlh_connect") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.connect.mlh") }
    end

    factory :customize_ux_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "customize_experience") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.customize_experience") }
    end

    factory :customize_feed_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "customize_feed") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.customize_feed") }
    end

    factory :start_discussion_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "start_discussion") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.start_discussion") }
    end

    factory :ask_question_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "ask_question") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.ask_question") }
    end

    factory :discuss_and_ask_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "discuss_and_ask") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.discuss_and_ask") }
    end

    factory :download_app_broadcast do
      title          { I18n.t("services.broadcasts.welcome_notification.generator.welcome", key: "download_app") }
      type_of        { "Welcome" }
      processed_html { I18n.t("broadcast.welcome.download_app") }
    end

    factory :announcement_broadcast do
      title          { "A Very Important Announcement" }
      type_of        { "Announcement" }
      processed_html { "<p>Hello, World!</p>" }
    end

    trait :with_tracking do
      processed_html do
        "Sloan here again! 👋 DEV is a friendly community. Why not introduce " \
          "yourself by leaving a comment in <a href='/welcome' onclick='trackNotification(event)'>" \
          "the welcome thread</a>!"
      end
    end
  end
end
