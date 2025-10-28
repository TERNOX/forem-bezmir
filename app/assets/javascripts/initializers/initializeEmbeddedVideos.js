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

function createYouTubeIframe(container) {
  const videoId = container.dataset.youtubeId;

  if (!videoId) {
    return null;
  }

  const iframe = document.createElement('iframe');
  const autoplaySeparator = videoId.indexOf('?') === -1 ? '?' : '&';
  const width = container.dataset.youtubeWidth;
  const height = container.dataset.youtubeHeight;
  const title = container.dataset.youtubeTitle || 'YouTube video player';

  iframe.src = `https://www.youtube-nocookie.com/embed/${videoId}${autoplaySeparator}autoplay=1`;
  if (width) {
    iframe.width = width;
  }
  if (height) {
    iframe.height = height;
  }
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

function initializeEmbeddedVideos(rootNode) {
  const scope = rootNode || document;
  const placeholders = scope.querySelectorAll('.embedded-video[data-youtube-id]');

  placeholders.forEach((placeholder) => {
    if (placeholder.dataset.youtubeInitialized === 'true') {
      return;
    }

    const trigger = placeholder.querySelector('.embedded-video__trigger');

    if (!trigger) {
      return;
    }

    placeholder.dataset.youtubeInitialized = 'true';

    loadHighestQualityThumbnail(placeholder);

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
  });
}

window.initializeEmbeddedVideos = initializeEmbeddedVideos;
