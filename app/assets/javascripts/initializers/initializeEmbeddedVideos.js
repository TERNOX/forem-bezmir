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
