const IMAGE_URL_PATTERN = /\.(apng|avif|bmp|gif|jpe?g|jfif|pjpeg|pjp|png|svg|webp|ico|heic|heif)(\?.*)?$/i;

const isImageHref = (href = '') => {
  const normalizedHref = href.split('#')[0];
  return (
    normalizedHref.startsWith('data:image/') ||
    IMAGE_URL_PATTERN.test(normalizedHref)
  );
};

const isModifierClick = (event) =>
  event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0;

const sanitizeText = (value = '') => value.replace(/\s+/g, ' ').trim();

const getFigureCaption = (link) => {
  const figure = link.closest('figure');
  if (!figure) {
    return '';
  }
  const caption = figure.querySelector('figcaption');
  return caption ? sanitizeText(caption.textContent) : '';
};

const getImageSource = (img) =>
  img?.currentSrc || img?.getAttribute('src') || img?.getAttribute('data-src') || '';

const createItemFromLink = (link) => {
  const image = link.querySelector('img');
  const itemSrc = link.getAttribute('href') || getImageSource(image);
  const altText = sanitizeText(
    link.dataset.lightboxAlt || image?.dataset?.lightboxAlt || image?.getAttribute('alt') || '',
  );
  const captionText = sanitizeText(
    link.dataset.lightboxCaption ||
      image?.dataset?.lightboxCaption ||
      getFigureCaption(link) ||
      altText,
  );

  return {
    src: itemSrc,
    displaySrc: getImageSource(image) || itemSrc,
    alt: altText,
    caption: captionText,
  };
};

const buildGallery = (galleryElement, galleryIndex) => {
  if (galleryElement.classList.contains('lightbox-gallery--enhanced')) {
    return null;
  }

  const rawLinks = Array.from(galleryElement.querySelectorAll('a[href]'));
  const imageLinks = rawLinks
    .map((link) => ({ link, image: link.querySelector('img') }))
    .filter(({ link, image }) => image && isImageHref(link.getAttribute('href') || ''));

  if (imageLinks.length === 0) {
    return null;
  }

  const galleryId =
    galleryElement.dataset.lightboxGallery || `article-gallery-${galleryIndex + 1}-${Date.now()}`;

  const items = imageLinks.map(({ link }) => createItemFromLink(link));

  let activeIndex = 0;
  let openHandler = null;

  const mainFigure = document.createElement('figure');
  mainFigure.className = 'lightbox-gallery__main';

  const mainButton = document.createElement('button');
  mainButton.type = 'button';
  mainButton.className = 'lightbox-gallery__main-button';

  const mainImage = document.createElement('img');
  mainImage.className = 'lightbox-gallery__main-image';
  mainImage.loading = 'lazy';
  mainButton.appendChild(mainImage);

  const mainCaption = document.createElement('figcaption');
  mainCaption.className = 'lightbox-gallery__caption';
  mainFigure.appendChild(mainButton);
  mainFigure.appendChild(mainCaption);

  const thumbnailsWrapper = document.createElement('div');
  thumbnailsWrapper.className = 'lightbox-gallery__thumbnails';

  const thumbnailButtons = items.map((item, index) => {
    const thumbnailButton = document.createElement('button');
    thumbnailButton.type = 'button';
    thumbnailButton.className = 'lightbox-gallery__thumbnail';

    const thumbnailImage = document.createElement('img');
    thumbnailImage.loading = 'lazy';
    thumbnailImage.src = item.displaySrc;
    thumbnailImage.alt = item.alt || '';
    thumbnailButton.appendChild(thumbnailImage);

    thumbnailButton.addEventListener('click', () => {
      if (activeIndex === index) {
        openHandler?.(index);
      } else {
        setActiveIndex(index);
      }
    });

    return thumbnailButton;
  });

  thumbnailButtons.forEach((button) => thumbnailsWrapper.appendChild(button));

  const updateMainButtonLabel = (item) => {
    const description = item.caption || item.alt;
    const label = description ? `Відкрити зображення у лайтбоксі: ${description}` : 'Відкрити зображення у лайтбоксі';
    mainButton.setAttribute('aria-label', label);
  };

  const setActiveIndex = (index) => {
    if (!items[index]) {
      return;
    }
    activeIndex = index;
    const item = items[index];
    mainImage.src = item.displaySrc;
    mainImage.alt = item.alt || '';
    mainCaption.textContent = item.caption || '';
    mainCaption.hidden = !item.caption;
    mainButton.dataset.lightboxIndex = String(index);
    updateMainButtonLabel(item);

    thumbnailButtons.forEach((button, buttonIndex) => {
      if (buttonIndex === index) {
        button.setAttribute('aria-current', 'true');
      } else {
        button.removeAttribute('aria-current');
      }
    });
  };

  galleryElement.innerHTML = '';
  galleryElement.classList.add('lightbox-gallery--enhanced');
  galleryElement.appendChild(mainFigure);
  if (items.length > 1) {
    galleryElement.appendChild(thumbnailsWrapper);
  }

  setActiveIndex(0);

  return {
    groupId: galleryId,
    items,
    mainTrigger: mainButton,
    setActiveIndex,
    registerOpenHandler(handler) {
      openHandler = handler;
    },
  };
};

const ensureOverlayElements = () => {
  if (ensureOverlayElements.cache) {
    return ensureOverlayElements.cache;
  }

  const container = document.createElement('div');
  container.className = 'image-lightbox-layer';
  container.setAttribute('aria-hidden', 'true');

  const backdrop = document.createElement('div');
  backdrop.className = 'image-lightbox-layer__backdrop';
  container.appendChild(backdrop);

  const dialog = document.createElement('div');
  dialog.className = 'image-lightbox';
  dialog.setAttribute('role', 'dialog');
  dialog.setAttribute('aria-modal', 'true');
  dialog.setAttribute('aria-label', 'Попередній перегляд зображення');

  const closeButton = document.createElement('button');
  closeButton.type = 'button';
  closeButton.className = 'image-lightbox__close';
  closeButton.setAttribute('aria-label', 'Закрити лайтбокс');
  closeButton.innerHTML = '<span aria-hidden="true">×</span>';
  dialog.appendChild(closeButton);

  const stage = document.createElement('div');
  stage.className = 'image-lightbox__stage';
  dialog.appendChild(stage);

  const prevButton = document.createElement('button');
  prevButton.type = 'button';
  prevButton.className = 'image-lightbox__nav image-lightbox__nav--prev';
  prevButton.setAttribute('aria-label', 'Попереднє зображення');
  prevButton.innerHTML = '<span aria-hidden="true">‹</span>';
  stage.appendChild(prevButton);

  const figure = document.createElement('figure');
  figure.className = 'image-lightbox__figure';
  stage.appendChild(figure);

  const image = document.createElement('img');
  image.className = 'image-lightbox__image';
  image.loading = 'lazy';
  figure.appendChild(image);

  const caption = document.createElement('figcaption');
  caption.className = 'image-lightbox__caption';
  caption.setAttribute('aria-live', 'polite');
  figure.appendChild(caption);

  const nextButton = document.createElement('button');
  nextButton.type = 'button';
  nextButton.className = 'image-lightbox__nav image-lightbox__nav--next';
  nextButton.setAttribute('aria-label', 'Наступне зображення');
  nextButton.innerHTML = '<span aria-hidden="true">›</span>';
  stage.appendChild(nextButton);

  container.appendChild(dialog);
  document.body.appendChild(container);

  ensureOverlayElements.cache = {
    container,
    backdrop,
    dialog,
    closeButton,
    prevButton,
    nextButton,
    image,
    caption,
  };

  return ensureOverlayElements.cache;
};

export const initializeArticleLightbox = () => {
  const articleBody = document.getElementById('article-body');
  if (!articleBody) {
    return;
  }

  const groups = new Map();
  const galleryStates = new Map();

  const defaultGroupId = `article-${articleBody.dataset.articleId || 'content'}`;
  const defaultItems = [];

  const overlayElements = ensureOverlayElements();
  let activeGroupId = null;
  let activeIndex = 0;
  let lastFocusedElement = null;

  const updateNavigationVisibility = (items) => {
    const hasMultiple = items.length > 1;
    overlayElements.prevButton.hidden = !hasMultiple;
    overlayElements.nextButton.hidden = !hasMultiple;
  };

  const updateOverlayContent = (item) => {
    overlayElements.container.classList.add('is-loading');
    overlayElements.image.onload = () => {
      overlayElements.container.classList.remove('is-loading');
    };
    overlayElements.image.onerror = () => {
      overlayElements.container.classList.remove('is-loading');
    };
    overlayElements.image.src = item.src;
    overlayElements.image.alt = item.alt || '';
    overlayElements.caption.textContent = item.caption || '';
    overlayElements.caption.hidden = !item.caption;
    if (overlayElements.image.complete && overlayElements.image.naturalWidth > 0) {
      overlayElements.container.classList.remove('is-loading');
    }
  };

  const closeLightbox = () => {
    if (overlayElements.container.getAttribute('aria-hidden') === 'true') {
      return;
    }
    overlayElements.container.classList.remove('is-visible');
    overlayElements.container.classList.remove('is-loading');
    overlayElements.container.setAttribute('aria-hidden', 'true');
    overlayElements.image.removeAttribute('src');
    overlayElements.caption.textContent = '';
    document.body.classList.remove('lightbox-open');
    activeGroupId = null;
    if (lastFocusedElement && document.contains(lastFocusedElement)) {
      lastFocusedElement.focus();
    }
    lastFocusedElement = null;
  };

  const syncGalleryState = () => {
    const state = galleryStates.get(activeGroupId);
    if (state) {
      state.setActiveIndex(activeIndex);
    }
  };

  const goToIndex = (index) => {
    if (activeGroupId === null) {
      return;
    }
    const items = groups.get(activeGroupId) || [];
    if (!items.length) {
      return;
    }
    const total = items.length;
    activeIndex = ((index % total) + total) % total;
    updateOverlayContent(items[activeIndex]);
    syncGalleryState();
  };

  const changeSlide = (step) => {
    if (activeGroupId === null) {
      return;
    }
    const items = groups.get(activeGroupId) || [];
    if (items.length < 2) {
      return;
    }
    goToIndex(activeIndex + step);
  };

  const openLightbox = (groupId, index) => {
    const items = groups.get(groupId);
    if (!items || !items[index]) {
      return;
    }

    activeGroupId = groupId;
    activeIndex = index;
    lastFocusedElement = document.activeElement instanceof HTMLElement ? document.activeElement : null;

    updateOverlayContent(items[index]);
    updateNavigationVisibility(items);
    overlayElements.container.classList.add('is-visible');
    overlayElements.container.setAttribute('aria-hidden', 'false');
    document.body.classList.add('lightbox-open');
    galleryStates.get(groupId)?.setActiveIndex(index);
    overlayElements.closeButton.focus();
  };

  const registerTrigger = (element, groupId, index) => {
    if (!element) {
      return;
    }
    element.dataset.lightboxGroup = groupId;
    element.dataset.lightboxIndex = String(index);
    element.classList.add('js-lightbox-trigger');
    element.addEventListener('click', (event) => {
      if (isModifierClick(event)) {
        return;
      }
      event.preventDefault();
      const triggerIndex = Number.parseInt(element.dataset.lightboxIndex || `${index}`, 10) || 0;
      openLightbox(groupId, triggerIndex);
    });
  };

  overlayElements.closeButton.addEventListener('click', closeLightbox);
  overlayElements.backdrop.addEventListener('click', closeLightbox);
  overlayElements.dialog.addEventListener('click', (event) => {
    if (event.target === overlayElements.dialog) {
      closeLightbox();
    }
  });
  overlayElements.prevButton.addEventListener('click', () => changeSlide(-1));
  overlayElements.nextButton.addEventListener('click', () => changeSlide(1));

  document.addEventListener('keydown', (event) => {
    if (overlayElements.container.getAttribute('aria-hidden') === 'true') {
      return;
    }
    if (event.key === 'Escape') {
      event.preventDefault();
      closeLightbox();
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault();
      changeSlide(-1);
    } else if (event.key === 'ArrowRight') {
      event.preventDefault();
      changeSlide(1);
    }
  });

  const galleries = Array.from(articleBody.querySelectorAll('.lightbox-gallery'));
  galleries.forEach((galleryElement, index) => {
    const gallery = buildGallery(galleryElement, index);
    if (!gallery) {
      return;
    }

    groups.set(gallery.groupId, gallery.items);
    galleryStates.set(gallery.groupId, {
      setActiveIndex: (value) => {
        gallery.setActiveIndex(value);
      },
    });

    gallery.registerOpenHandler((requestedIndex) => openLightbox(gallery.groupId, requestedIndex));
    registerTrigger(gallery.mainTrigger, gallery.groupId, 0);
  });

  const remainingLinks = Array.from(articleBody.querySelectorAll('a[href]')).filter((link) => {
    if (!link.querySelector('img')) {
      return false;
    }
    if (link.closest('.lightbox-gallery')) {
      return false;
    }
    if (link.dataset.noLightbox === 'true' || link.classList.contains('js-no-lightbox')) {
      return false;
    }
    return isImageHref(link.getAttribute('href') || '');
  });

  remainingLinks.forEach((link) => {
    const item = createItemFromLink(link);
    if (!item.src) {
      return;
    }
    const index = defaultItems.push(item) - 1;
    registerTrigger(link, defaultGroupId, index);
  });

  if (defaultItems.length) {
    groups.set(defaultGroupId, defaultItems);
  }
};
