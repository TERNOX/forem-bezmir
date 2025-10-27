const YOUTUBE_IFRAME_SELECTOR = '.ltag__youtube-iframe';
const OBSERVER_ROOT_MARGIN = '200px 0px';
const OBSERVER_THRESHOLD = 0.25;

let intersectionObserver;

const loadIframe = (iframe) => {
  const { youtubeSrc } = iframe.dataset;

  if (!youtubeSrc) {
    return;
  }

  if (iframe.src === youtubeSrc) {
    return;
  }

  iframe.src = youtubeSrc;
  iframe.dataset.youtubeLoaded = 'true';
};

const initializeObserver = () => {
  if (intersectionObserver || !('IntersectionObserver' in window)) {
    return intersectionObserver;
  }

  intersectionObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        const iframe = entry.target;

        if (!entry.isIntersecting) {
          return;
        }

        loadIframe(iframe);
        observer.unobserve(iframe);
      });
    },
    {
      rootMargin: OBSERVER_ROOT_MARGIN,
      threshold: OBSERVER_THRESHOLD,
    },
  );

  return intersectionObserver;
};

export const initializeYoutubeIframeLazyLoad = () => {
  const iframes = document.querySelectorAll(YOUTUBE_IFRAME_SELECTOR);

  if (!iframes.length) {
    return;
  }

  if (!('IntersectionObserver' in window)) {
    iframes.forEach(loadIframe);
    return;
  }

  const observer = initializeObserver();

  iframes.forEach((iframe) => {
    if (iframe.dataset.youtubeObserverAttached) {
      return;
    }

    iframe.dataset.youtubeObserverAttached = 'true';
    observer.observe(iframe);
  });
};
