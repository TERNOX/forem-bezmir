import { h } from 'preact';
import PropTypes from 'prop-types';
import { useEffect, useLayoutEffect, useMemo, useRef } from 'preact/hooks';
import { locale } from '@utilities/locale';
import { Toolbar } from './Toolbar';
import { handleImagePasted } from './pasteImageHelpers';
import { handleURLPasted } from './pasteURLHelpers';
import {
  handleImageUploadSuccess,
  handleImageUploading,
  handleImageUploadFailure,
} from './imageUploadHelpers';
import { handleImageDrop, onDragOver, onDragExit } from './dragAndDropHelpers';
import { usePasteImage } from '@utilities/pasteImage';
import { useDragAndDrop } from '@utilities/dragAndDrop';
import { fetchSearch } from '@utilities/search';
import { AutocompleteTriggerTextArea } from '@crayons/AutocompleteTriggerTextArea';

export const EditorBody = ({
  onChange,
  defaultValue,
  switchHelpContext,
  version,
}) => {
  const textAreaRef = useRef(null);
  const videoEnabled = useMemo(() => {
    const main = typeof document !== 'undefined' ? document.getElementById('main-content') : null;
    return (main?.dataset?.videoEnabled || 'false') === 'true';
  }, []);

  const imageHandlers = useMemo(
    () => ({
      uploading: handleImageUploading(textAreaRef),
      success: handleImageUploadSuccess(textAreaRef),
      failure: handleImageUploadFailure(textAreaRef),
    }),
    [textAreaRef],
  );

  const videoHandlers = useMemo(() => {
    if (!videoEnabled) {
      return { enabled: false };
    }

    return {
      enabled: true,
      uploading: handleImageUploading(textAreaRef, 'video'),
      success: handleImageUploadSuccess(textAreaRef, 'video'),
      failure: handleImageUploadFailure(textAreaRef, 'video'),
    };
  }, [textAreaRef, videoEnabled]);

  const { setElement } = useDragAndDrop({
    onDrop: handleImageDrop(
      imageHandlers.uploading,
      imageHandlers.success,
      imageHandlers.failure,
      { videoHandlers },
    ),
    onDragOver,
    onDragExit,
  });

  const setPasteElement = usePasteImage({
    onPaste: handleImagePasted(
      imageHandlers.uploading,
      imageHandlers.success,
      imageHandlers.failure,
      { videoHandlers },
    ),
  });

  useLayoutEffect(() => {
    if (textAreaRef.current) {
      setElement(textAreaRef.current);
      setPasteElement(textAreaRef.current);
    }
  });

  // Attach URL paste handler for embed prompt
  useEffect(() => {
    const textarea = textAreaRef.current;
    if (!textarea) return;

    const handler = handleURLPasted(textAreaRef);
    textarea.addEventListener('paste', handler);
    return () => textarea.removeEventListener('paste', handler);
  }, []);

  return (
    <div
      data-testid="article-form__body"
      className="crayons-article-form__body drop-area text-padding"
    >
      <Toolbar version={version} textAreaId="article_body_markdown" />
      <AutocompleteTriggerTextArea
        triggerCharacter="@"
        maxSuggestions={6}
        searchInstructionsMessage="Type to search for a user"
        ref={textAreaRef}
        fetchSuggestions={(username) =>
          fetchSearch('usernames', { username }).then(({ result }) =>
            result.map((user) => ({ ...user, value: user.username })),
          )
        }
        autoResize
        onChange={onChange}
        onFocus={switchHelpContext}
        aria-label="Post Content"
        name="body_markdown"
        id="article_body_markdown"
        defaultValue={defaultValue}
        placeholder={locale('core.editor_body_placeholder')}
        className="crayons-textfield crayons-textfield--ghost crayons-article-form__body__field ff-monospace fs-l h-100"
      />
    </div>
  );
};

EditorBody.propTypes = {
  onChange: PropTypes.func.isRequired,
  defaultValue: PropTypes.string.isRequired,
  switchHelpContext: PropTypes.func.isRequired,
  version: PropTypes.string.isRequired,
};

EditorBody.displayName = 'EditorBody';
