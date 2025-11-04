import { validateFileInputs } from '../packs/validateFileInputs';
import { getVideoConfig, formatTemplate } from './components/mediaConfig';

export function previewArticle(payload, successCb, failureCb) {
  fetch('/articles/preview', {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'X-CSRF-Token': window.csrfToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      article_body: payload,
    }),
    credentials: 'same-origin',
  })
    .then(async (response) => {
      const payload = await response.json();

      if (response.status !== 200) {
        throw payload;
      }

      return payload;
    })
    .then(successCb)
    .catch(failureCb);
}

export function getArticle() {}

function processPayload(payload) {
  const {
    /* eslint-disable no-unused-vars */
    previewShowing,
    helpShowing,
    previewResponse,
    helpHTML,
    imageManagementShowing,
    moreConfigShowing,
    errors,
    /* eslint-enable no-unused-vars */
    ...neededPayload
  } = payload;
  return neededPayload;
}

export function submitArticle({ payload, onSuccess, onError }) {
  const method = payload.id ? 'PUT' : 'POST';
  const url = payload.id ? `/articles/${payload.id}` : '/articles';
  fetch(url, {
    method,
    headers: {
      Accept: 'application/json',
      'X-CSRF-Token': window.csrfToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      article: processPayload(payload),
    }),
    credentials: 'same-origin',
  })
    .then((response) => response.json())
    .then((response) => {
      if (response.current_state_path) {
        onSuccess();
        window.location.replace(response.current_state_path);
      } else {
        onError(response);
      }
    })
    .catch(onError);
}

function generateUploadFormdata(payload, fieldName = 'image') {
  const token = window.csrfToken;
  const formData = new FormData();
  formData.append('authenticity_token', token);

  Object.entries(payload[fieldName]).forEach(([_, value]) =>
    formData.append(`${fieldName}[]`, value),
  );

  return formData;
}

export function generateMainImage({ payload, successCb, failureCb, signal }) {
  fetch('/image_uploads', {
    method: 'POST',
    headers: {
      'X-CSRF-Token': window.csrfToken,
    },
    body: generateUploadFormdata(payload),
    credentials: 'same-origin',
    signal,
  })
    .then((response) => response.json())
    .then((json) => {
      if (json.error) {
        throw new Error(json.error);
      }
      const { links } = json;
      const { image } = payload;
      return successCb({ links, image, kind: json.kind || 'image', markdown: json.markdown });
    })
    .catch((message) => failureCb(message));
}

export function generateVideoUpload({ payload, successCb, failureCb, signal }) {
  fetch('/video_uploads', {
    method: 'POST',
    headers: {
      'X-CSRF-Token': window.csrfToken,
    },
    body: generateUploadFormdata(payload, 'video'),
    credentials: 'same-origin',
    signal,
  })
    .then((response) => response.json())
    .then((json) => {
      if (json.error) {
        throw new Error(json.error);
      }
      const { links } = json;
      const { video } = payload;
      return successCb({ links, video, kind: json.kind || 'video', markdown: json.markdown });
    })
    .catch((message) => failureCb(message));
}

/**
 * Processes images for upload.
 *
 * @param {FileList} images Images to be uploaded.
 * @param {Function} handleImageSuccess The handler that runs when the image is uploaded successfully.
 * @param {Function} handleImageFailure The handler that runs when the image upload fails.
 */
export function processImageUpload(
  images,
  handleImageUploading,
  handleImageSuccess,
  handleImageFailure,
) {
  // Currently only one image is supported for upload.
  if (images.length > 0 && validateFileInputs()) {
    const payload = { image: images };

    handleImageUploading();
    generateMainImage({
      payload,
      successCb: handleImageSuccess,
      failureCb: handleImageFailure,
    });
  }
}

export function processVideoUpload(
  videos,
  handleVideoUploading,
  handleVideoSuccess,
  handleVideoFailure,
) {
  if (videos.length === 0) {
    return;
  }

  const { limitMb, limitBytes, tooLargeMessageTemplate } = getVideoConfig();
  const oversizeFile = Array.from(videos).find((file) => file.size > limitBytes);

  if (oversizeFile) {
    const sizeMb = (oversizeFile.size / (1024 * 1024)).toFixed(2);
    const message = formatTemplate(tooLargeMessageTemplate, {
      size: sizeMb,
      max: limitMb,
    });

    handleVideoFailure({ message: message || `Video file is too large (${sizeMb} MB). The limit is ${limitMb} MB.` });
    return;
  }

  if (!validateFileInputs()) {
    return;
  }

  const payload = { video: videos };

  handleVideoUploading();
  generateVideoUpload({
    payload,
    successCb: handleVideoSuccess,
    failureCb: handleVideoFailure,
  });
}
