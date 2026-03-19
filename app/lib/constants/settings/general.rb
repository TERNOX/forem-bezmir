module Constants
  module Settings
    module General
      IMAGE_PLACEHOLDER = "https://url/image.png".freeze

      def self.details
        {
          ahoy_tracking: {
            description: I18n.t("lib.constants.settings.general.ahoy_tracking.description")
          },
          billboard_enabled_countries: {
            description: I18n.t("lib.constants.settings.general.billboard_enabled_countries.description")
          },
          contact_email: {
            description: I18n.t("lib.constants.settings.general.contact_email.description"),
            placeholder: "hello@example.com"
          },
          credit_prices_in_cents: {
            small: {
              description: I18n.t("lib.constants.settings.general.credit.small.description"),
              placeholder: ""
            },
            medium: {
              description: I18n.t("lib.constants.settings.general.credit.medium.description"),
              placeholder: ""
            },
            large: {
              description: I18n.t("lib.constants.settings.general.credit.large.description"),
              placeholder: ""
            },
            xlarge: {
              description: I18n.t("lib.constants.settings.general.credit.xlarge.description"),
              placeholder: ""
            }
          },
          favicon_url: {
            description: I18n.t("lib.constants.settings.general.favicon.description"),
            placeholder: IMAGE_PLACEHOLDER
          },
          ga_tracking_id: {
            description: I18n.t("lib.constants.settings.general.ga_tracking.description"),
            placeholder: ""
          },
          ga_analytics_4_id: {
            description: I18n.t("lib.constants.settings.general.ga_analytics_4.description"),
            placeholder: ""
          },
          cookie_banner_user_context: {
            description: I18n.t("lib.constants.settings.general.cookie_banner_user_context.description"),
            placeholder: "off"
          },
          coolie_banner_platform_context: {
            description: I18n.t("lib.constants.settings.general.coolie_banner_platform_context.description"),
            placeholder: "off"
          },
          health_check_token: {
            description: I18n.t("lib.constants.settings.general.health.description"),
            placeholder: I18n.t("lib.constants.settings.general.health.placeholder")
          },
          logo_png: {
            description: I18n.t("lib.constants.settings.general.logo_png.description"),
            placeholder: IMAGE_PLACEHOLDER
          },
          logo_svg: {
            description: I18n.t("lib.constants.settings.general.logo_svg.description"),
            placeholder: IMAGE_PLACEHOLDER
          },
          main_social_image: {
            description: I18n.t("lib.constants.settings.general.main_social.description"),
            placeholder: IMAGE_PLACEHOLDER
          },
          mailchimp_api_key: {
            description: I18n.t("lib.constants.settings.general.mailchimp_api.description"),
            placeholder: ""
          },
          mailchimp_newsletter_id: {
            description: I18n.t("lib.constants.settings.general.mailchimp_news.description"),
            placeholder: ""
          },
          mailchimp_tag_moderators_id: {
            description: I18n.t("lib.constants.settings.general.mailchimp_tag_mod.description"),
            placeholder: ""
          },
          mailchimp_community_moderators_id: {
            description: I18n.t("lib.constants.settings.general.mailchimp_mod.description"),
            placeholder: ""
          },
          mascot_image_url: {
            description: I18n.t("lib.constants.settings.general.mascot_image.description"),
            placeholder: IMAGE_PLACEHOLDER
          },
          mascot_user_id: {
            description: I18n.t("lib.constants.settings.general.mascot_user.description"),
            placeholder: "1"
          },
          meta_keywords: {
            description: "",
            placeholder: I18n.t("lib.constants.settings.general.meta_keywords.description")
          },
          onboarding_newsletter_content: {
            description: I18n.t("lib.constants.settings.general.onboarding_newsletter_content.description"),
            placeholder: I18n.t("lib.constants.settings.general.onboarding_newsletter_content.placeholder")
          },
          onboarding_newsletter_opt_in_head: {
            description: I18n.t("lib.constants.settings.general.onboarding_newsletter_opt_in_head.description"),
            placeholder: I18n.t("lib.constants.settings.general.onboarding_newsletter_opt_in_head.placeholder")
          },
          onboarding_newsletter_opt_in_subhead: {
            description: I18n.t("lib.constants.settings.general.onboarding_newsletter_opt_in_subhead.description"),
            placeholder: I18n.t("lib.constants.settings.general.onboarding_newsletter_opt_in_subhead.placeholder")
          },
          geos_with_allowed_default_email_opt_in: {
            description: I18n.t("lib.constants.settings.general.geos_with_allowed_default_email_opt_in.description"),
            placeholder: I18n.t("lib.constants.settings.general.geos_with_allowed_default_email_opt_in.placeholder")
          },
          periodic_email_digest: {
            description: I18n.t("lib.constants.settings.general.periodic.description"),
            placeholder: 2
          },
          sidebar_tags: {
            description: I18n.t("lib.constants.settings.general.sidebar.description"),
            placeholder: I18n.t("lib.constants.settings.general.sidebar.placeholder")
          },
          news_sitemap_tags: {
            description: I18n.t("lib.constants.settings.general.news_sitemap_tags.description"),
            placeholder: I18n.t("lib.constants.settings.general.news_sitemap_tags.placeholder")
          },
          news_sitemap_organization_ids: {
            description: I18n.t("lib.constants.settings.general.news_sitemap_organization_ids.description"),
            placeholder: I18n.t("lib.constants.settings.general.news_sitemap_organization_ids.placeholder")
          },
          stripe_api_key: {
            description: I18n.t("lib.constants.settings.general.stripe_api.description"),
            placeholder: "sk_live_...."
          },
          stripe_publishable_key: {
            description: I18n.t("lib.constants.settings.general.stripe_key.description"),
            placeholder: "pk_live_...."
          },
          subscription_product_name: {
            description: I18n.t("lib.constants.settings.general.subscription_product_name.description"),
            placeholder: "DEV++"
          },
          subscription_landing_page_url: {
            description: I18n.t("lib.constants.settings.general.subscription_landing_page_url.description"),
            placeholder: "/++"
          },
          subscriber_icon_url: {
            description: I18n.t("lib.constants.settings.general.subscriber_icon_url.description"),
            placeholder: IMAGE_PLACEHOLDER
          },
          suggested_tags: {
            description: I18n.t("lib.constants.settings.general.tags.description"),
            placeholder: I18n.t("lib.constants.settings.general.tags.placeholder")
          },
          twitter_hashtag: {
            description: I18n.t("lib.constants.settings.general.hashtag.description"),
            placeholder: I18n.t("lib.constants.settings.general.hashtag.placeholder")
          },
          enable_video_upload: {
            description: I18n.t("lib.constants.settings.general.enable_video_upload.description")
          },
          video_upload_max_file_size_mb: {
            description: I18n.t("lib.constants.settings.general.video_upload_max_file_size_mb.description"),
            placeholder: 50
          },
          video_encoder_key: {
            description: I18n.t("lib.constants.settings.general.video.description"),
            placeholder: ""
          },
          video_upload_access_key_id: {
            description: I18n.t("lib.constants.settings.general.video_upload_access_key_id.description"),
            placeholder: I18n.t("lib.constants.settings.general.video_upload_access_key_id.placeholder")
          },
          video_upload_secret_access_key: {
            description: I18n.t("lib.constants.settings.general.video_upload_secret_access_key.description"),
            placeholder: I18n.t("lib.constants.settings.general.video_upload_secret_access_key.placeholder")
          },
          video_upload_bucket: {
            description: I18n.t("lib.constants.settings.general.video_upload_bucket.description"),
            placeholder: I18n.t("lib.constants.settings.general.video_upload_bucket.placeholder")
          },
          video_upload_region: {
            description: I18n.t("lib.constants.settings.general.video_upload_region.description"),
            placeholder: I18n.t("lib.constants.settings.general.video_upload_region.placeholder")
          },
          video_upload_custom_endpoint: {
            description: I18n.t("lib.constants.settings.general.video_upload_custom_endpoint.description"),
            placeholder: I18n.t("lib.constants.settings.general.video_upload_custom_endpoint.placeholder")
          },
          video_cdn_base_url: {
            description: I18n.t("lib.constants.settings.general.video_cdn_base_url.description"),
            placeholder: I18n.t("lib.constants.settings.general.video_cdn_base_url.placeholder")
          }
        }
      end
    end
  end
end
