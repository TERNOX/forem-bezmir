import { h } from 'preact';
import PropTypes from 'prop-types';
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'preact/hooks';
import { Toolbar } from './Toolbar';
import { handleImagePasted } from './pasteImageHelpers';
import {
  handleImageUploadSuccess,
  handleImageUploading,
  handleImageUploadFailure,
} from './imageUploadHelpers';
import {
  handleImageDrop,
  onDragOver,
  onDragExit,
  handleImageFailure as handleImageFailureMessage,
} from './dragAndDropHelpers';
import { WysiwygEditor } from './WysiwygEditor';
import { AutocompleteTriggerTextArea } from '@crayons/AutocompleteTriggerTextArea';
import { useDragAndDrop } from '@utilities/dragAndDrop';
import { locale } from '@utilities/locale';
import { usePasteImage } from '@utilities/pasteImage';
import { fetchSearch } from '@utilities/search';

export const EditorBody = ({
  onChange,
  defaultValue,
  switchHelpContext,
  version,
}) => {
  const textAreaRef = useRef(null);
  const [mode, setMode] = useState('markdown');
  const [wysiwygEditor, setWysiwygEditor] = useState(null);
  const [markdownValue, setMarkdownValue] = useState(defaultValue);
  const videoEnabled = useMemo(() => {
    const main = typeof document !== 'undefined' ? document.getElementById('main-content') : null;
    return (main?.dataset?.videoEnabled || 'false') === 'true';
  }, []);

  useEffect(() => {
    setMarkdownValue(defaultValue);

    if (textAreaRef.current && textAreaRef.current.value !== defaultValue) {
      textAreaRef.current.value = defaultValue;
    }
  }, [defaultValue]);

  useEffect(() => {
    if (version !== 'v2' || typeof window === 'undefined') {
      return;
    }

    const storedMode = window.localStorage.getItem('editor-v2-mode');
    if (storedMode === 'wysiwyg' || storedMode === 'markdown') {
      setMode(storedMode);
    }
  }, [version]);

  useEffect(() => {
    if (version !== 'v2' || typeof window === 'undefined') {
      return;
    }

    window.localStorage.setItem('editor-v2-mode', mode);
  }, [mode, version]);

  const isWysiwygEnabled = version === 'v2';
  const isWysiwygActive = isWysiwygEnabled && mode === 'wysiwyg';

  const updateTextareaValue = useCallback(
    (markdown) => {
      if (!textAreaRef.current) {
        return;
      }

      if (textAreaRef.current.value === markdown) {
        return;
      }

      textAreaRef.current.value = markdown;
      const inputEvent = new Event('input', { bubbles: true });
      textAreaRef.current.dispatchEvent(inputEvent);
    },
    [],
  );

  const insertMarkdownIntoEditor = useCallback(
    (markdown) => {
      if (!wysiwygEditor) {
        return;
      }

      const trimmedMarkdown = (markdown || '').trim();
      if (!trimmedMarkdown) {
        return;
      }

      const imageMatch = trimmedMarkdown.match(/^!\[(.*?)\]\((.*?)(?: "(.*?)")?\)$/);

      if (imageMatch) {
        const [, alt = '', src = '', title] = imageMatch;
        const attributes = { src, alt };
        if (title) {
          attributes.title = title;
        }
        wysiwygEditor.chain().focus().setImage(attributes).run();
        return;
      }

      wysiwygEditor.chain().focus().insertContent(trimmedMarkdown).run();
    },
    [wysiwygEditor],
  );

  const imageHandlers = useMemo(
    () => {
      if (isWysiwygActive && wysiwygEditor) {
        return {
          uploading: () => wysiwygEditor.chain().focus().run(),
          success: (response) => {
            const { markdown, links = [] } = response;
            const fallbackMarkdown = `![Image description](${links[0] || ''})`;
            insertMarkdownIntoEditor((markdown || fallbackMarkdown).trim());
          },
          failure: handleImageFailureMessage,
        };
      }

      return {
        uploading: handleImageUploading(textAreaRef),
        success: handleImageUploadSuccess(textAreaRef),
        failure: handleImageUploadFailure(textAreaRef),
      };
    },
    [insertMarkdownIntoEditor, isWysiwygActive, textAreaRef, wysiwygEditor],
  );

  const videoHandlers = useMemo(() => {
    if (!videoEnabled) {
      return { enabled: false };
    }

    if (isWysiwygActive && wysiwygEditor) {
      return {
        enabled: true,
        uploading: () => wysiwygEditor.chain().focus().run(),
        success: (response) => {
          const { markdown, links = [] } = response;
          const fallbackMarkdown = `![](${links[0] || ''})`;
          insertMarkdownIntoEditor((markdown || fallbackMarkdown).trim());
        },
        failure: handleImageFailureMessage,
      };
    }

    return {
      enabled: true,
      uploading: handleImageUploading(textAreaRef, 'video'),
      success: handleImageUploadSuccess(textAreaRef, 'video'),
      failure: handleImageUploadFailure(textAreaRef, 'video'),
    };
  }, [insertMarkdownIntoEditor, isWysiwygActive, textAreaRef, videoEnabled, wysiwygEditor]);

  const { setElement: setDragElement } = useDragAndDrop({
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
    if (isWysiwygActive && wysiwygEditor) {
      setDragElement(wysiwygEditor.view.dom);
      setPasteElement(wysiwygEditor.view.dom);
      return;
    }

    if (textAreaRef.current) {
      setDragElement(textAreaRef.current);
      setPasteElement(textAreaRef.current);
    }
  }, [isWysiwygActive, setDragElement, setPasteElement, wysiwygEditor]);

  const handleModeChange = useCallback(
    (nextMode) => {
      if (!isWysiwygEnabled) {
        return;
      }

      if (nextMode === 'wysiwyg') {
        const currentMarkdown = textAreaRef.current?.value ?? markdownValue;
        setMarkdownValue(currentMarkdown);
      }

      setMode(nextMode);

      if (nextMode === 'markdown' && textAreaRef.current) {
        textAreaRef.current.focus();
      }

      if (nextMode === 'wysiwyg' && wysiwygEditor) {
        wysiwygEditor.chain().focus().run();
      }
    },
    [isWysiwygEnabled, markdownValue, wysiwygEditor],
  );

  const handleWysiwygMarkdownChange = useCallback(
    (markdown) => {
      setMarkdownValue(markdown);
      updateTextareaValue(markdown);
    },
    [updateTextareaValue],
  );

  const handleTextareaChange = useCallback(
    (event) => {
      setMarkdownValue(event.target.value);
      onChange(event);
    },
    [onChange],
  );

  return (
    <div
      data-testid="article-form__body"
      className="crayons-article-form__body drop-area text-padding"
    >
      <Toolbar
        version={version}
        textAreaId="article_body_markdown"
        mode={mode}
        onModeChange={handleModeChange}
        wysiwygEnabled={isWysiwygEnabled}
        wysiwygToolbarProps={{
          editor: wysiwygEditor,
          onImageUploadStart: () => wysiwygEditor?.chain().focus().run(),
          onImageUploadSuccess: insertMarkdownIntoEditor,
          onImageUploadError: () => {},
          onVideoUploadStart: () => wysiwygEditor?.chain().focus().run(),
          onVideoUploadSuccess: insertMarkdownIntoEditor,
          onVideoUploadError: () => {},
          videoEnabled,
        }}
      />
      {isWysiwygActive && (
        <WysiwygEditor
          markdown={markdownValue}
          onMarkdownChange={handleWysiwygMarkdownChange}
          onEditorReady={setWysiwygEditor}
          switchHelpContext={switchHelpContext}
        />
      )}
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
        onChange={handleTextareaChange}
        onFocus={switchHelpContext}
        aria-label="Post Content"
        name="body_markdown"
        id="article_body_markdown"
        defaultValue={defaultValue}
        placeholder={locale('core.editor_body_placeholder')}
        className="crayons-textfield crayons-textfield--ghost crayons-article-form__body__field ff-monospace fs-l h-100"
        aria-hidden={isWysiwygActive}
        style={isWysiwygActive ? { display: 'none' } : undefined}
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
