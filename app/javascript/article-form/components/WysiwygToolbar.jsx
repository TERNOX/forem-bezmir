import { h } from 'preact';
import PropTypes from 'prop-types';
import { ImageUploader } from './ImageUploader';
import { VideoUploader } from './VideoUploader';
import { ButtonNew as Button } from '@crayons';

const BUTTON_VARIANT_ACTIVE = 'primary';
const BUTTON_VARIANT_DEFAULT = 'secondary';

export const WysiwygToolbar = ({
  editor,
  onImageUploadStart,
  onImageUploadSuccess,
  onImageUploadError,
  onVideoUploadStart,
  onVideoUploadSuccess,
  onVideoUploadError,
  videoEnabled,
  additionalItems = [],
}) => {
  if (!editor) {
    return (
      <div className="editor-toolbar wysiwyg-toolbar" role="toolbar" aria-label="Formatting toolbar">
        <span className="color-base-60">Loading editor…</span>
      </div>
    );
  }

  const formattingButtons = [
    {
      key: 'bold',
      label: 'Bold',
      content: <strong>B</strong>,
      command: () => editor.chain().focus().toggleBold().run(),
      isActive: () => editor.isActive('bold'),
    },
    {
      key: 'italic',
      label: 'Italic',
      content: <em>I</em>,
      command: () => editor.chain().focus().toggleItalic().run(),
      isActive: () => editor.isActive('italic'),
    },
    {
      key: 'strike',
      label: 'Strikethrough',
      content: <span className="ff-monospace">S</span>,
      command: () => editor.chain().focus().toggleStrike().run(),
      isActive: () => editor.isActive('strike'),
    },
    {
      key: 'code',
      label: 'Code',
      content: <span className="ff-monospace">&lt;/&gt;</span>,
      command: () => editor.chain().focus().toggleCode().run(),
      isActive: () => editor.isActive('code'),
    },
    {
      key: 'heading',
      label: 'Heading',
      content: <span className="ff-monospace">H2</span>,
      command: () => editor.chain().focus().toggleHeading({ level: 2 }).run(),
      isActive: () => editor.isActive('heading', { level: 2 }),
    },
    {
      key: 'bulletList',
      label: 'Bullet list',
      content: <span>&bull; List</span>,
      command: () => editor.chain().focus().toggleBulletList().run(),
      isActive: () => editor.isActive('bulletList'),
    },
    {
      key: 'orderedList',
      label: 'Numbered list',
      content: <span>1. List</span>,
      command: () => editor.chain().focus().toggleOrderedList().run(),
      isActive: () => editor.isActive('orderedList'),
    },
    {
      key: 'blockquote',
      label: 'Quote',
      content: <span>&ldquo;Quote&rdquo;</span>,
      command: () => editor.chain().focus().toggleBlockquote().run(),
      isActive: () => editor.isActive('blockquote'),
    },
    {
      key: 'codeBlock',
      label: 'Code block',
      content: <span className="ff-monospace">{`{ }`}</span>,
      command: () => editor.chain().focus().toggleCodeBlock().run(),
      isActive: () => editor.isActive('codeBlock'),
    },
  ];

  const toggleLink = () => {
    const previousUrl = editor.getAttributes('link').href || '';
    const href = typeof window !== 'undefined' ? window.prompt('Enter URL', previousUrl) : null;

    if (href === null) {
      return;
    }

    if (href === '') {
      editor.chain().focus().extendMarkRange('link').unsetLink().run();
      return;
    }

    editor.chain().focus().extendMarkRange('link').setLink({ href }).run();
  };

  return (
    <div className="editor-toolbar wysiwyg-toolbar" role="toolbar" aria-label="Formatting toolbar">
      <ImageUploader
        editorVersion="v2"
        buttonProps={{
          variant: BUTTON_VARIANT_DEFAULT,
          className: 'wysiwyg-toolbar__button',
          tooltip: 'Upload image',
          onClick: () => editor.chain().focus().run(),
        }}
        onImageUploadStart={onImageUploadStart}
        onImageUploadSuccess={onImageUploadSuccess}
        onImageUploadError={onImageUploadError}
      />
      {videoEnabled && (
        <VideoUploader
          buttonProps={{
            variant: BUTTON_VARIANT_DEFAULT,
            className: 'wysiwyg-toolbar__button',
            tooltip: 'Upload video',
            onClick: () => editor.chain().focus().run(),
          }}
          onVideoUploadStart={onVideoUploadStart}
          onVideoUploadSuccess={onVideoUploadSuccess}
          onVideoUploadError={onVideoUploadError}
        />
      )}
      <Button
        variant={editor.isActive('link') ? BUTTON_VARIANT_ACTIVE : BUTTON_VARIANT_DEFAULT}
        className="wysiwyg-toolbar__button"
        type="button"
        aria-pressed={editor.isActive('link')}
        onClick={toggleLink}
      >
        Link
      </Button>
      {formattingButtons.map(({ key, label, content, command, isActive }) => (
        <Button
          key={key}
          variant={isActive() ? BUTTON_VARIANT_ACTIVE : BUTTON_VARIANT_DEFAULT}
          className="wysiwyg-toolbar__button"
          type="button"
          aria-pressed={isActive()}
          onClick={command}
        >
          {content}
          <span className="screen-reader-only">{label}</span>
        </Button>
      ))}
      <Button
        variant={BUTTON_VARIANT_DEFAULT}
        className="wysiwyg-toolbar__button"
        type="button"
        onClick={() => editor.chain().focus().undo().run()}
        disabled={!editor.can().chain().focus().undo().run()}
        aria-label="Undo"
      >
        ↺
      </Button>
      <Button
        variant={BUTTON_VARIANT_DEFAULT}
        className="wysiwyg-toolbar__button"
        type="button"
        onClick={() => editor.chain().focus().redo().run()}
        disabled={!editor.can().chain().focus().redo().run()}
        aria-label="Redo"
      >
        ↻
      </Button>
      {additionalItems.map((item, index) => (
        <span key={item?.key ?? index} className="wysiwyg-toolbar__additional">
          {item}
        </span>
      ))}
    </div>
  );
};

WysiwygToolbar.propTypes = {
  editor: PropTypes.object,
  onImageUploadStart: PropTypes.func,
  onImageUploadSuccess: PropTypes.func,
  onImageUploadError: PropTypes.func,
  onVideoUploadStart: PropTypes.func,
  onVideoUploadSuccess: PropTypes.func,
  onVideoUploadError: PropTypes.func,
  videoEnabled: PropTypes.bool.isRequired,
  additionalItems: PropTypes.arrayOf(PropTypes.node),
};

WysiwygToolbar.displayName = 'WysiwygToolbar';
