const MEASUREMENT_CONTEXT = (() => {
  const canvas = document.createElement('canvas');
  return canvas.getContext ? canvas.getContext('2d') : null;
})();

function parseSize(value) {
  if (!value) return 0;
  const parsed = parseFloat(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function measureLabelWidth(spoiler, label) {
  if (!MEASUREMENT_CONTEXT) return null;

  const style = window.getComputedStyle(spoiler);
  const baseFontSize = parseSize(style.fontSize) || 16;
  const pseudoFontSize = baseFontSize * 0.8;
  const fontFamily = style.fontFamily || 'sans-serif';
  const fontWeight = style.fontWeight === 'normal' ? 600 : style.fontWeight || 600;

  MEASUREMENT_CONTEXT.font = `${fontWeight} ${pseudoFontSize}px ${fontFamily}`;
  return MEASUREMENT_CONTEXT.measureText(label).width;
}

function updateLabelVisibility(spoiler) {
  const label = spoiler.getAttribute('data-spoiler-label');
  if (!label) return;

  const labelWidth = measureLabelWidth(spoiler, label);
  if (!labelWidth) return;

  const style = window.getComputedStyle(spoiler);
  const availableWidth =
    spoiler.clientWidth - (parseSize(style.paddingLeft) + parseSize(style.paddingRight));

  spoiler.dataset.spoilerLabelHidden = labelWidth > availableWidth ? 'true' : 'false';
}

function setSpoilerState(spoiler, expanded) {
  const next = expanded ? 'true' : 'false';
  spoiler.dataset.spoilerExpanded = next;
  spoiler.setAttribute('aria-expanded', next);
}

function toggleSpoiler(event) {
  if (event.type === 'keydown' && !['Enter', ' '].includes(event.key)) {
    return;
  }

  event.preventDefault();
  const spoiler = event.currentTarget;
  const isExpanded = spoiler.dataset.spoilerExpanded === 'true';
  setSpoilerState(spoiler, !isExpanded);
}

function initializeSpoiler(spoiler) {
  if (spoiler.dataset.spoilerInitialized === 'true') return;

  spoiler.dataset.spoilerInitialized = 'true';
  spoiler.setAttribute('role', 'button');
  setSpoilerState(spoiler, spoiler.getAttribute('aria-expanded') === 'true');

  spoiler.addEventListener('click', toggleSpoiler);
  spoiler.addEventListener('keydown', toggleSpoiler);

  updateLabelVisibility(spoiler);

  if (typeof ResizeObserver !== 'undefined') {
    const observer = new ResizeObserver(() => updateLabelVisibility(spoiler));
    observer.observe(spoiler);
  }
}

export function initializeSpoilers(root = document) {
  const spoilers = root.querySelectorAll('[data-spoiler]');
  spoilers.forEach(initializeSpoiler);
}
