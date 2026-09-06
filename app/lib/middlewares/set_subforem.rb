# config/initializers/middlewares/set_subforem.rb
module Middlewares
  class SetSubforem
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)

      domain = request.GET["passed_domain"].presence || request.host
      RequestStore.store[:default_subforem_id]     = Subforem.cached_default_id
      RequestStore.store[:subforem_id]             = Subforem.cached_id_by_domain(domain)
      RequestStore.store[:root_subforem_id]        = Subforem.cached_root_id
      RequestStore.store[:root_subforem_domain]    = Subforem.cached_root_domain
      RequestStore.store[:default_subforem_domain] = Subforem.cached_default_domain
      
      # Cache the current subforem's domain for URL generation
      if RequestStore.store[:subforem_id].present?
        RequestStore.store[:subforem_domain] = Subforem.cached_id_to_domain_hash[RequestStore.store[:subforem_id]]
      end

      # Call Rails (or next middleware) to get the response
      status, headers, body = @app.call(env)

      # POST-PROCESS HEADERS HERE
      begin
        # Example logic: if a subforem is found, we do custom cookie manipulation
        if RequestStore.store[:subforem_id].present?
          parsed = PublicSuffix.parse(request.host, default_rule: nil)
          subdomain_regexp = /^([^.]+)\.#{parsed.sld}\.#{parsed.tld}$/

          if request.host =~ subdomain_regexp
            # Remove your session cookie (or any other cookie) from subdomain
            Rack::Utils.delete_cookie_header!(
              headers,
              ApplicationConfig["SESSION_KEY"],
              domain: request.host
            )

            # Also remove 'remember_user_token' or other cookies if needed
            Rack::Utils.delete_cookie_header!(
              headers,
              "remember_user_token",
              domain: request.host
            )
          end
        end

        # Set Content-Security-Policy header to allow embedding in iframes for all subforems
        headers.delete("X-Frame-Options")
        allowed_domains = Subforem.cached_all_domains + [Settings::General.app_domain]
        subforem_sources = allowed_domains.map { |d| "https://#{d}" }
        existing_csp = headers["Content-Security-Policy"].to_s
        directives = existing_csp.split(";").map(&:strip).reject(&:blank?)
        # Preserve any frame-ancestors a controller set explicitly (e.g. the
        # auth-pass iframe allows an organization custom domain) and merge the
        # subforem domains in, rather than clobbering it.
        existing = directives.find { |d| d.start_with?("frame-ancestors") }
        existing_sources = existing ? existing.sub(/\Aframe-ancestors\b/, "").split : []
        directives.reject! { |directive| directive.start_with?("frame-ancestors") }
        merged_sources = (existing_sources + subforem_sources).uniq
        directives << "frame-ancestors #{merged_sources.join(' ')}"
        headers["Content-Security-Policy"] = directives.join("; ")

      rescue PublicSuffix::DomainInvalid
        Rails.logger.error("Invalid domain: #{request.host}")
      end

      [status, headers, body]
    end
  end
end
