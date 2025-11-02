/* global checkUserLoggedIn */

function removeExistingCSRF() {
  var csrfTokenMeta = document.querySelector("meta[name='csrf-token']");
  var csrfParamMeta = document.querySelector("meta[name='csrf-param']");
  if (csrfTokenMeta && csrfParamMeta) {
    csrfTokenMeta.parentNode.removeChild(csrfTokenMeta);
    csrfParamMeta.parentNode.removeChild(csrfParamMeta);
  }
}

function fetchBaseData() {
  fetch('/async_info/base_data')
    .then((response) => response.json())
    .then(
      ({
        token,
        param,
        broadcast,
        user,
        creator,
        client_geolocation,
        default_email_optin_allowed,
      }) => {
        if (token) {
          removeExistingCSRF();
        }

        const newCsrfParamMeta = document.createElement('meta');
        newCsrfParamMeta.name = 'csrf-param';
        newCsrfParamMeta.content = param;
        document.head.appendChild(newCsrfParamMeta);

        const newCsrfTokenMeta = document.createElement('meta');
        newCsrfTokenMeta.name = 'csrf-token';
        newCsrfTokenMeta.content = token;
        document.head.appendChild(newCsrfTokenMeta);
        document.body.dataset.loaded = 'true';

        if (broadcast) {
          document.body.dataset.broadcast = broadcast;
        }

        if (checkUserLoggedIn() && user) {
          document.body.dataset.user = user;
          document.body.dataset.creator = creator;
          document.body.dataset.clientGeolocation =
            JSON.stringify(client_geolocation);
          document.body.dataset.default_email_optin_allowed =
            default_email_optin_allowed;
          const userJson = JSON.parse(user);
          browserStoreCache('set', user);

          const themePreference = userJson.prefer_os_color_scheme ? 'system' : userJson.config_theme;
          if (window.__foremTheme) {
            let fallback = userJson.config_theme;
            if (themePreference === 'system') {
              if (document.body && document.body.classList.contains('dark-theme')) {
                fallback = 'dark_theme';
              } else if (document.body && document.body.classList.contains('light-theme')) {
                fallback = 'light_theme';
              }
            }

            window.__foremTheme.setPreference(themePreference, {
              bodyClass: userJson.config_body_class,
              fallbackTheme: fallback,
            });
          } else {
            document.body.className = userJson.config_body_class;
          }

          if (window && window.ReactNativeWebView) {
            window.ReactNativeWebView.postMessage(JSON.stringify({
              action: 'user',
              data: userJson,
            }));
            // If path is "/" send a "go_home" RN message
            if (window.location.pathname === "/" && userJson.saw_onboarding === true) {
              window.ReactNativeWebView.postMessage(JSON.stringify({
                action: 'go_home',
              }));
            }
          }

          const isForemWebview = navigator.userAgent === 'ForemWebView/1';
          if (isForemWebview || window.frameElement) { // Hide top bar and footer when loaded within iframe
            document.body.classList.add("hidden-shell");
          }

          setTimeout(() => {
            if (typeof ga === 'function') {
              ga('set', 'userId', userJson.id);
            }
            if (typeof gtag === 'function') {
              gtag('set', 'user_Id', userJson.id);
            }
          }, 400);
        } else if (checkUserLoggedIn()){
          // Reload page if user is present but document user check is not
          delete document.body.dataset.user;
          delete document.body.dataset.creator;
          browserStoreCache('remove');
          location.reload();
        } else {
          // Ensure user data is not exposed if no one is logged in
          delete document.body.dataset.user;
          delete document.body.dataset.creator;
          browserStoreCache('remove');
        }
      },
    );
}

function initializeBodyData() {
  fetchBaseData();
}
