const STEAM_IFRAME_SELECTOR = '.ltag__steam-iframe';
let bodyClassObserver;
let prefersColorSchemeQuery;

const getPreferredTheme = () => {
  if (document.body.classList.contains('dark-theme')) {
    return 'dark';
  }

  if (document.body.classList.contains('light-theme')) {
    return 'light';
  }

  return prefersColorSchemeQuery && prefersColorSchemeQuery.matches
    ? 'dark'
    : 'light';
};

const applyThemeToIframes = () => {
  const theme = getPreferredTheme();
  document.querySelectorAll(STEAM_IFRAME_SELECTOR).forEach((iframe) => {
    iframe.style.backgroundColor = 'var(--card-bg)';
    iframe.style.colorScheme = theme;
  });
};

const ensurePrefersColorSchemeListener = () => {
  if (prefersColorSchemeQuery) {
    return;
  }

  prefersColorSchemeQuery = window.matchMedia('(prefers-color-scheme: dark)');
  prefersColorSchemeQuery.addEventListener('change', applyThemeToIframes);
};

const ensureBodyClassObserver = () => {
  if (bodyClassObserver) {
    return;
  }

  bodyClassObserver = new MutationObserver(applyThemeToIframes);
  bodyClassObserver.observe(document.body, {
    attributes: true,
    attributeFilter: ['class'],
  });
};

export const initializeSteamIframeColorScheme = () => {
  if (!document.querySelector(STEAM_IFRAME_SELECTOR)) {
    return;
  }

  ensurePrefersColorSchemeListener();
  ensureBodyClassObserver();
  applyThemeToIframes();
};
