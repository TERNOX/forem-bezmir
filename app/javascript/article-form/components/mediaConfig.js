const DEFAULT_VIDEO_LIMIT_MB = 50;
const DEFAULT_TOO_LARGE_MESSAGE =
  'Video file is too large (%{size} MB). The limit is %{max} MB.';

function getMainElement() {
  if (typeof document === 'undefined') {
    return null;
  }

  return document.getElementById('main-content');
}

export function getVideoConfig() {
  const main = getMainElement();
  const limitMb = Number(main?.dataset?.videoUploadMax) || DEFAULT_VIDEO_LIMIT_MB;
  const tooLargeMessageTemplate =
    main?.dataset?.videoTooLargeMessage || DEFAULT_TOO_LARGE_MESSAGE;

  return {
    limitMb,
    limitBytes: limitMb * 1024 * 1024,
    tooLargeMessageTemplate,
  };
}

export function formatTemplate(template, replacements = {}) {
  if (!template) {
    return '';
  }

  return template.replace(/%\{(\w+)\}/g, (_, key) => {
    if (Object.prototype.hasOwnProperty.call(replacements, key)) {
      return replacements[key];
    }

    return '';
  });
}
