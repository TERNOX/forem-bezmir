const boundHandlers = new WeakMap();
let overlayElement;
let overlayImage;
let overlayCaption;
let overlayCloseButton;
let overlayNextButton;
let overlayPrevButton;
let activeGalleryItems = [];
let activeGalleryIndex = -1;

const bodyClassName = 'c-lightbox-open';

const handleKeydown = (event) => {
  if (!overlayElement || overlayElement.hidden) {
    return;
  }

  if (event.key === 'Escape') {
    event.preventDefault();
    overlayCloseButton.click();
  } else if (event.key === 'ArrowRight') {
    event.preventDefault();
    overlayNextButton.click();
  } else if (event.key === 'ArrowLeft') {
    event.preventDefault();
    overlayPrevButton.click();
  }
};

const updateNavigationAvailability = () => {
  const hasMultipleItems = activeGalleryItems.length > 1;
  overlayNextButton.toggleAttribute('hidden', !hasMultipleItems);
  overlayPrevButton.toggleAttribute('hidden', !hasMultipleItems);

  overlayNextButton.setAttribute('aria-disabled', String(!hasMultipleItems));
  overlayPrevButton.setAttribute('aria-disabled', String(!hasMultipleItems));
};

const setCaption = (textContent) => {
  if (!overlayCaption) {
    return;
  }

  const text = textContent ? textContent.trim() : '';
  overlayCaption.textContent = text;
  overlayCaption.toggleAttribute('hidden', text.length === 0);
};

const displayImage = (item) => {
  overlayElement.classList.add('c-lightbox--loading');
  overlayImage.onload = () => {
    overlayElement.classList.remove('c-lightbox--loading');
  };
  overlayImage.onerror = () => {
    overlayElement.classList.remove('c-lightbox--loading');
  };

  overlayImage.src = item.src;
  overlayImage.alt = item.alt || item.caption || '';
  setCaption(item.caption);
};

const renderActiveItem = (index) => {
  if (!overlayElement) {
    return;
  }

  if (activeGalleryItems.length === 0) {
    return;
  }

  const clampedIndex = index % activeGalleryItems.length;
  activeGalleryIndex = clampedIndex < 0 ? activeGalleryItems.length + clampedIndex : clampedIndex;
  const item = activeGalleryItems[activeGalleryIndex];

  if (!item) {
    return;
  }

  displayImage(item);
  updateNavigationAvailability();
};

const closeLightbox = () => {
  if (!overlayElement) {
    return;
  }

  overlayElement.hidden = true;
  document.removeEventListener('keydown', handleKeydown, true);
  document.body.classList.remove(bodyClassName);
  overlayElement.classList.remove('c-lightbox--loading');
  activeGalleryItems = [];
  activeGalleryIndex = -1;
};

const showNextItem = () => {
  if (activeGalleryItems.length === 0) {
    return;
  }

  renderActiveItem(activeGalleryIndex + 1);
};

const showPreviousItem = () => {
  if (activeGalleryItems.length === 0) {
    return;
  }

  renderActiveItem(activeGalleryIndex - 1);
};

const ensureOverlay = () => {
  if (overlayElement) {
    return;
  }

  overlayElement = document.createElement('div');
  overlayElement.className = 'c-lightbox';
  overlayElement.setAttribute('role', 'dialog');
  overlayElement.setAttribute('aria-modal', 'true');
  overlayElement.setAttribute('aria-label', 'Image preview');
  overlayElement.hidden = true;
  overlayElement.innerHTML = `
    <div class="c-lightbox__container" role="document">
      <button type="button" class="c-lightbox__close" data-action="close" aria-label="Close image preview">
        <span aria-hidden="true">&times;</span>
      </button>
      <button type="button" class="c-lightbox__nav c-lightbox__nav--prev" data-action="prev" aria-label="Show previous image">
        <span aria-hidden="true">&#10094;</span>
      </button>
      <button type="button" class="c-lightbox__nav c-lightbox__nav--next" data-action="next" aria-label="Show next image">
        <span aria-hidden="true">&#10095;</span>
      </button>
      <div class="c-lightbox__loading" aria-hidden="true"></div>
      <figure class="c-lightbox__figure">
        <img class="c-lightbox__image" alt="" />
        <figcaption class="c-lightbox__caption" hidden></figcaption>
      </figure>
    </div>
  `;

  overlayImage = overlayElement.querySelector('.c-lightbox__image');
  overlayCaption = overlayElement.querySelector('.c-lightbox__caption');
  overlayCloseButton = overlayElement.querySelector('[data-action="close"]');
  overlayNextButton = overlayElement.querySelector('[data-action="next"]');
  overlayPrevButton = overlayElement.querySelector('[data-action="prev"]');

  overlayCloseButton.addEventListener('click', closeLightbox);
  overlayNextButton.addEventListener('click', showNextItem);
  overlayPrevButton.addEventListener('click', showPreviousItem);

  overlayElement.addEventListener('click', (event) => {
    if (event.target === overlayElement) {
      closeLightbox();
    }
  });

  document.body.appendChild(overlayElement);
};

const openLightbox = (items, index) => {
  ensureOverlay();

  activeGalleryItems = items;
  overlayElement.hidden = false;
  document.body.classList.add(bodyClassName);
  document.addEventListener('keydown', handleKeydown, true);
  renderActiveItem(index);
  overlayCloseButton.focus();
};

const getCaptionForAnchor = (anchor) => {
  if (!anchor) {
    return '';
  }

  if (anchor.dataset.lightboxCaption) {
    return anchor.dataset.lightboxCaption;
  }

  const figure = anchor.closest('figure');
  if (figure) {
    const figCaption = figure.querySelector('figcaption');
    if (figCaption) {
      return figCaption.textContent.trim();
    }
  }

  const imageElement = anchor.querySelector('img');
  if (!imageElement) {
    return '';
  }

  const title = imageElement.getAttribute('title');
  if (title && title.trim().length > 0) {
    return title.trim();
  }

  const alt = imageElement.getAttribute('alt');
  if (alt && alt.trim().length > 0) {
    return alt.trim();
  }

  return '';
};

const gatherGalleryItems = (anchors) => {
  const galleryMap = new Map();

  anchors.forEach((anchor) => {
    const imageElement = anchor.querySelector('img');
    if (!imageElement) {
      return;
    }

    const galleryId = anchor.dataset.lightboxGallery || 'article-body';
    const galleryItems = galleryMap.get(galleryId) || [];

    galleryItems.push({
      anchor,
      src: anchor.getAttribute('href'),
      alt: imageElement.getAttribute('alt') || '',
      caption: getCaptionForAnchor(anchor),
    });

    galleryMap.set(galleryId, galleryItems);
  });

  return galleryMap;
};

const flattenGalleryStructure = (galleryElement) => {
  const anchors = Array.from(
    galleryElement.querySelectorAll('a.article-body-image-wrapper'),
  );

  if (!anchors.length) {
    return [];
  }

  const preservedNodes = Array.from(galleryElement.childNodes).filter((node) => {
    return !anchors.includes(node);
  });

  galleryElement.textContent = '';

  const featuredAnchor = anchors[0];
  featuredAnchor.classList.add('lightbox-gallery__featured');
  galleryElement.appendChild(featuredAnchor);

  if (anchors.length > 1) {
    const thumbnailsWrapper = document.createElement('div');
    thumbnailsWrapper.className = 'lightbox-gallery__thumbnails';

    anchors.slice(1).forEach((anchor) => {
      anchor.classList.add('lightbox-gallery__thumbnail');
      thumbnailsWrapper.appendChild(anchor);
    });

    galleryElement.appendChild(thumbnailsWrapper);
  }

  preservedNodes.forEach((node) => {
    if (node.nodeType === Node.TEXT_NODE && node.textContent.trim() === '') {
      return;
    }

    if (node.nodeType === Node.ELEMENT_NODE && node.childNodes.length === 0) {
      return;
    }

    galleryElement.appendChild(node);
  });

  galleryElement.classList.add('lightbox-gallery--enhanced');

  return [featuredAnchor, ...anchors.slice(1)];
};

const assignGalleryIdentifiers = (articleBody) => {
  const inlineGalleries = Array.from(
    articleBody.querySelectorAll('.lightbox-gallery'),
  );

  inlineGalleries.forEach((galleryElement, galleryIndex) => {
    const explicitId =
      galleryElement.dataset.lightboxGallery ||
      galleryElement.getAttribute('data-gallery');
    const galleryId =
      explicitId && explicitId.trim().length > 0
        ? explicitId.trim()
        : `article-inline-gallery-${galleryIndex + 1}`;

    galleryElement.dataset.lightboxGallery = galleryId;

    const anchors = flattenGalleryStructure(galleryElement);
    anchors.forEach((anchor) => {
      anchor.dataset.lightboxGallery = galleryId;
    });
  });
};

const determineGalleryForAnchor = (anchor) => {
  if (anchor.dataset.lightboxGallery) {
    return anchor.dataset.lightboxGallery;
  }

  const directValue = anchor.getAttribute('data-gallery');
  if (directValue && directValue.trim().length > 0) {
    return directValue.trim();
  }

  const groupedContainer = anchor.closest('[data-lightbox-gallery]');
  if (groupedContainer) {
    const containerValue = groupedContainer.getAttribute('data-lightbox-gallery');
    if (containerValue && containerValue.trim().length > 0) {
      return containerValue.trim();
    }
  }

  return 'article-body';
};

const bindLightboxHandlers = (anchors, galleryMap) => {
  anchors.forEach((anchor) => {
    const galleryId = determineGalleryForAnchor(anchor);
    anchor.dataset.lightboxGallery = galleryId;

    const items = galleryMap.get(galleryId) || [];
    const existingHandler = boundHandlers.get(anchor);

    if (existingHandler) {
      anchor.removeEventListener('click', existingHandler);
    }

    const handler = (event) => {
      event.preventDefault();
      const itemIndex = items.findIndex((item) => item.anchor === anchor);
      if (itemIndex === -1) {
        return;
      }

      openLightbox(items, itemIndex);
    };

    anchor.addEventListener('click', handler);
    boundHandlers.set(anchor, handler);
  });
};

export const initializeImageLightbox = () => {
  const articleBody = document.getElementById('article-body');
  if (!articleBody) {
    return;
  }

  assignGalleryIdentifiers(articleBody);

  const anchors = Array.from(
    articleBody.querySelectorAll('a.article-body-image-wrapper'),
  );

  if (!anchors.length) {
    return;
  }

  anchors.forEach((anchor) => {
    anchor.dataset.lightboxGallery = determineGalleryForAnchor(anchor);
  });

  const galleryMap = gatherGalleryItems(anchors);
  bindLightboxHandlers(anchors, galleryMap);
};
