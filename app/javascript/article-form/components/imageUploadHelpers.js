import { handleImageFailure } from './dragAndDropHelpers';

// Placeholder text displayed while an image is uploading
const PLACEHOLDERS = {
  image: '![Uploading image](...)',
  video: '![Uploading video](...)',
};

function placeholderFor(kind) {
  return PLACEHOLDERS[kind] || PLACEHOLDERS.image;
}

/**
 * Handles image uploading by showing UPLOADING_IMAGE_PLACEHOLDER text.
 *
 * @param {useRef} textAreaRef The reference of the text area with content.
 */
export function handleImageUploading(textAreaRef, kind = 'image') {
  return function () {
    // Function is within the component to be able to access
    // textarea ref.
    const editableBodyElement = textAreaRef.current;

    const { selectionStart, selectionEnd, value } = editableBodyElement;
    const placeholder = placeholderFor(kind);
    const before = value.substring(0, selectionStart);
    const after = value.substring(selectionEnd, value.length);
    const newSelectionStart = `${before}\n${placeholder}`
      .length;

    editableBodyElement.value = `${before}\n${placeholder}\n${after}`;
    editableBodyElement.selectionStart = newSelectionStart;
    editableBodyElement.selectionEnd = newSelectionStart;
  };
}

/**
 * Handles image upload successfully by replacing UPLOADING_IMAGE_PLACEHOLDER with image link.
 *
 * @param {useRef} textAreaRef The reference of the text area with content.
 */
export function handleImageUploadSuccess(textAreaRef, kind = 'image') {
  return function (response) {
    // Function is within the component to be able to access
    // textarea ref.
    const editableBodyElement = textAreaRef.current;
    const { links } = response;
    const placeholder = placeholderFor(kind);
    const markdownImageLink =
      response.markdown ||
      `${kind === 'video' ? `<video controls src="${links[0]}"></video>` : `![Image description](${links[0]})`}\n`;
    const { selectionStart, selectionEnd, value } = editableBodyElement;
    if (value.includes(placeholder)) {
      const newSelectedStart =
        value.indexOf(placeholder, 0) +
        markdownImageLink.length;

      editableBodyElement.value = value.replace(
        placeholder,
        markdownImageLink,
      );
      editableBodyElement.selectionStart = newSelectedStart;
      editableBodyElement.selectionEnd = newSelectedStart;
    } else {
      const before = value.substring(0, selectionStart);
      const after = value.substring(selectionEnd, value.length);

      editableBodyElement.value = `${before}\n${markdownImageLink}\n${after}`;
      editableBodyElement.selectionStart =
        selectionStart + markdownImageLink.length;
      editableBodyElement.selectionEnd = editableBodyElement.selectionStart;
    }

    // Dispatching a new event so that linkstate, https://github.com/developit/linkstate,
    // the function used to create the onChange prop gets called correctly.
    editableBodyElement.dispatchEvent(new Event('input'));
  };
}

/**
 * Handles image upload failure by removing UPLOADING_IMAGE_PLACEHOLDER text and showing error.
 *
 * @param {useRef} textAreaRef The reference of the text area with content.
 */
export function handleImageUploadFailure(textAreaRef, kind = 'image') {
  return function (message) {
    // Function is within the component to be able to access
    // textarea ref.
    handleImageFailure(message);
    const editableBodyElement = textAreaRef.current;

    const { value } = editableBodyElement;
    const placeholder = placeholderFor(kind);
    if (value.includes(`\n${placeholder}\n`)) {
      const newSelectionStart = value.indexOf(
        `\n${placeholder}\n`,
        0,
      );

      editableBodyElement.value = value.replace(
        `\n${placeholder}\n`,
        '',
      );
      editableBodyElement.selectionStart = newSelectionStart;
      editableBodyElement.selectionEnd = newSelectionStart;
    }
  };
}
