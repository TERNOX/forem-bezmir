# Be sure to restart your server when you modify this file.
#
# config.load_defaults was bumped to 7.0 (#23413), so the standard Rails 7.0
# framework defaults are now applied automatically. The only thing kept here is
# the fork's CUSTOM default_headers — the CSP / Permissions-Policy that allow the
# fork's embedded YouTube player and image sources. This is NOT a Rails default,
# so it must persist after the load_defaults upgrade.
Rails.application.config.action_dispatch.default_headers = {
  "X-Frame-Options" => "SAMEORIGIN",
  "X-XSS-Protection" => "0",
  "X-Content-Type-Options" => "nosniff",
  "X-Download-Options" => "noopen",
  "X-Permitted-Cross-Domain-Policies" => "none",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "autoplay=(self \"https://www.youtube.com\")",
  "Content-Security-Policy" => "frame-src https://www.youtube.com https: data:; img-src https://i.ytimg.com https://img.youtube.com data: https:;"
}
