import { addSnackbarItem } from '../../Snackbar';
import { processImageUpload, processVideoUpload } from '../actions';

const VIDEO_MIME_PATTERN = /^video\//i;
const VIDEO_EXTENSION_PATTERN = /\.(mp4|webm|mov|m4v)$/i;

function detectFileKind(files) {
  const [file] = files || [];
  if (!file) {
    return 'image';
  }

  if (VIDEO_MIME_PATTERN.test(file.type)) {
    return 'video';
  }

  if (VIDEO_EXTENSION_PATTERN.test(file.name || '')) {
    return 'video';
  }

  return 'image';
}

function getMultiFileMessage(kind) {
  if (kind === 'video') {
    return 'Only one video can be dropped at a time.';
  }

  return 'Only one image can be dropped at a time.';
}

/**
 * Determines if at least one type of drag and drop datum type matches the data transfer type to match.
 *
 * @param {string[]} types An array of data transfer types.
 * @param {string} dataTransferType The data transfer type to match.
 */
export function matchesDataTransferType(
  types = [],
  dataTransferType = 'Files',
) {
  return types.some((type) => type === dataTransferType);
}

// TODO: Document functions
export function handleImageDrop(
  handleImageUploading,
  handleImageSuccess,
  handleImageFailure,
  options = {},
) {
  const { videoHandlers } = options;
  return function (event) {
    event.preventDefault();

    if (!matchesDataTransferType(event.dataTransfer.types)) {
      return;
    }

    event.currentTarget
      .closest('.drop-area')
      .classList.remove('drop-area--active');

    const { files } = event.dataTransfer;
    const kind = detectFileKind(files);

    if (files.length > 1) {
      addSnackbarItem({
        message: getMultiFileMessage(kind),
        addCloseButton: true,
      });
      return;
    }

    if (kind === 'video') {
      if (!videoHandlers?.enabled) {
        addSnackbarItem({
          message: 'Video uploads are not enabled for this community yet.',
          addCloseButton: true,
        });
        return;
      }

      processVideoUpload(
        files,
        videoHandlers.uploading,
        videoHandlers.success,
        videoHandlers.failure,
      );
      return;
    }

    processImageUpload(
      files,
      handleImageUploading,
      handleImageSuccess,
      handleImageFailure,
    );
  };
}

/**
 * Dragover handler for the editor
 *
 * @param {DragEvent} event the drag event.
 */
export function onDragOver(event) {
  event.preventDefault();
  event.currentTarget.closest('.drop-area').classList.add('drop-area--active');
}

/**
 * DragExit handler for the editor
 *
 * @param {DragEvent} event the drag event.
 */
export function onDragExit(event) {
  event.preventDefault();
  event.currentTarget
    .closest('.drop-area')
    .classList.remove('drop-area--active');
}

/**
 * Handler for when image upload fails.
 *
 * @param {Error} error an error
 * @param {string} error.message an error message
 */
export function handleImageFailure({ message }) {
  addSnackbarItem({
    message,
    addCloseButton: true,
  });
}
