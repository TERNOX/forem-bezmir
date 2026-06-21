const THUMBNAIL_QUALITIES = [
  'maxresdefault',
  'sddefault',
  'hqdefault',
  'mqdefault',
  'default',
];

const LOW_RES_WIDTH = 120;
const LOW_RES_HEIGHT = 90;

function loadHighestQualityThumbnail(container) {
  const thumbnail = container.querySelector('.embedded-video__thumbnail');
  const videoId = container.dataset.youtubeThumbnailId;

  if (!thumbnail || !videoId) {
    return;
  }

  let resolved = false;

  const tryQuality = (index) => {
    if (resolved || index >= THUMBNAIL_QUALITIES.length) {
      return;
    }

    const quality = THUMBNAIL_QUALITIES[index];
    const probe = new Image();

    probe.decoding = 'async';
    probe.loading = 'eager';

    probe.addEventListener('error', () => {
      tryQuality(index + 1);
    });

    probe.addEventListener('load', () => {
      if (resolved) {
        return;
      }

      if (
        quality !== 'default' &&
        probe.naturalWidth <= LOW_RES_WIDTH &&
        probe.naturalHeight <= LOW_RES_HEIGHT
      ) {
        tryQuality(index + 1);
        return;
      }

      thumbnail.src = probe.src;
      thumbnail.dataset.youtubeThumbnailQuality = quality;
      resolved = true;
    });

    probe.src = `https://img.youtube.com/vi/${videoId}/${quality}.jpg`;
  };

  if (thumbnail.complete && thumbnail.naturalWidth === 0) {
    thumbnail.removeAttribute('src');
  }

  tryQuality(0);
}

// Rebuild the thumbnail trigger purely from the container's data-* attributes.
// This is required when a placeholder is restored from a navigation cache
// (InstantClick swaps the DOM in from an HTML cache, so the in-memory trigger
// template and the original <button> are gone — only the <iframe> survives).
function buildTriggerFromData(placeholder) {
  const thumbnailId = placeholder.dataset.youtubeThumbnailId;

  if (!thumbnailId) {
    return null;
  }

  const trigger = document.createElement('button');
  trigger.type = 'button';
  trigger.className = 'embedded-video__trigger';
  trigger.style.width = '100%';

  if (placeholder.dataset.youtubePlayLabel) {
    trigger.setAttribute('aria-label', placeholder.dataset.youtubePlayLabel);
  }

  const img = document.createElement('img');
  img.className = 'embedded-video__thumbnail';
  img.src = `https://img.youtube.com/vi/${thumbnailId}/mqdefault.jpg`;
  img.dataset.youtubeThumbnailQuality = 'mqdefault';
  img.alt = placeholder.dataset.youtubeThumbnailAlt || '';
  img.loading = 'lazy';
  img.decoding = 'async';

  trigger.appendChild(img);

  return trigger;
}

function attachTrigger(placeholder, trigger) {
  trigger.addEventListener('click', () => {
    if (placeholder.dataset.youtubeLoaded === 'true') {
      return;
    }

    const iframe = createYouTubeIframe(placeholder);

    if (!iframe) {
      return;
    }

    placeholder.dataset.youtubeLoaded = 'true';
    placeholder.classList.add('embedded-video--loaded');
    trigger.replaceWith(iframe);
  });
}

// Tear a loaded player back down to its thumbnail. Used when a player is found
// in the "loaded" state during (re)initialization — i.e. it was restored from a
// navigation cache (InstantClick or bfcache). An autoplaying iframe must never
// survive a navigation, and a cached iframe can also come back with a broken
// (huge) computed height, so we always rebuild the lightweight thumbnail.
function restoreThumbnail(placeholder) {
  const iframe = placeholder.querySelector('iframe');

  if (iframe) {
    iframe.remove();
  }

  placeholder.classList.remove('embedded-video--loaded');
  delete placeholder.dataset.youtubeLoaded;

  let trigger = placeholder.querySelector('.embedded-video__trigger');

  if (!trigger) {
    trigger = placeholder._youtubeTriggerTemplate
      ? placeholder._youtubeTriggerTemplate.cloneNode(true)
      : buildTriggerFromData(placeholder);

    if (trigger) {
      placeholder.appendChild(trigger);
    }
  }

  // Force re-initialization so the (possibly brand new) trigger gets a handler.
  delete placeholder.dataset.youtubeInitialized;
}

function resetAllEmbeddedVideos() {
  document
    .querySelectorAll('.embedded-video[data-youtube-id]')
    .forEach((placeholder) => {
      if (
        placeholder.querySelector('iframe') ||
        placeholder.dataset.youtubeLoaded === 'true'
      ) {
        restoreThumbnail(placeholder);
      }
    });

  // Re-attach triggers for anything we just reset.
  initializeEmbeddedVideos();
}

let lifecycleListenersInitialized = false;

function initializeLifecycleListeners() {
  if (lifecycleListenersInitialized) {
    return;
  }

  // Full-page back/forward cache (bfcache) restores do NOT re-run
  // initializePage, so reset here. InstantClick navigations are handled by the
  // reset built into initializeEmbeddedVideos (called on every InstantClick
  // 'change').
  window.addEventListener('pageshow', (event) => {
    if (event.persisted) {
      resetAllEmbeddedVideos();
    }
  });

  lifecycleListenersInitialized = true;
}

function createYouTubeIframe(container) {
  const embedSrc = buildYouTubeEmbedUrl(container);

  if (!embedSrc) {
    return null;
  }

  const iframe = document.createElement('iframe');
  const width = container.dataset.youtubeWidth;
  const title = container.dataset.youtubeTitle || 'YouTube video player';

  iframe.src = embedSrc;
  if (width) {
    iframe.width = width;
  }
  // Keep the iframe a normal in-flow 16/9 box (this is what renders correctly on
  // a fresh click). The runaway-height case only happened when a *cached* page
  // was restored with this iframe still present; that is now handled by resetting
  // the player back to its thumbnail on (re)initialization, so no extra CSS is
  // needed here.
  iframe.style.aspectRatio = '16 / 9';
  iframe.setAttribute('title', title);
  iframe.setAttribute('allowfullscreen', '');
  iframe.setAttribute(
    'allow',
    'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share',
  );
  iframe.setAttribute('loading', 'lazy');
  iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');

  return iframe;
}

function buildYouTubeEmbedUrl(container) {
  const presetSrc = container.dataset.youtubeSrc;
  if (presetSrc) {
    return presetSrc;
  }

  const videoId = container.dataset.youtubeId;

  if (!videoId) {
    return null;
  }

  const [pureId, rawQuery = ''] = videoId.split('?');
  if (!pureId) {
    return null;
  }

  const params = new URLSearchParams(rawQuery);
  params.set('autoplay', '1');
  params.set('rel', '0');
  params.set('modestbranding', '1');
  params.set('playsinline', '1');

  const queryString = params.toString();

  return `https://www.youtube.com/embed/${pureId}${queryString ? `?${queryString}` : ''}`;
}

function initializeEmbeddedVideos(rootNode) {
  const scope = rootNode || document;
  const placeholders = scope.querySelectorAll('.embedded-video[data-youtube-id]');

  placeholders.forEach((placeholder) => {
    // A player restored from a navigation cache (InstantClick / bfcache) comes
    // back already "loaded" (its iframe is in the cached HTML). Autoplaying
    // iframes must not survive navigation, and a cached iframe can render at a
    // broken height, so tear it back down to the thumbnail before continuing.
    if (
      placeholder.querySelector('iframe') ||
      placeholder.dataset.youtubeLoaded === 'true'
    ) {
      restoreThumbnail(placeholder);
    }

    if (placeholder.dataset.youtubeInitialized === 'true') {
      return;
    }

    let trigger = placeholder.querySelector('.embedded-video__trigger');

    if (!trigger) {
      trigger = buildTriggerFromData(placeholder);

      if (!trigger) {
        return;
      }

      placeholder.appendChild(trigger);
    }

    if (!placeholder._youtubeTriggerTemplate) {
      placeholder._youtubeTriggerTemplate = trigger.cloneNode(true);
    }

    placeholder.dataset.youtubeInitialized = 'true';

    loadHighestQualityThumbnail(placeholder);

    attachTrigger(placeholder, trigger);
  });

  initializeLifecycleListeners();
}

window.initializeEmbeddedVideos = initializeEmbeddedVideos;
