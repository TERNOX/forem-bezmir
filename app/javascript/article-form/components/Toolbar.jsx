import { h } from 'preact';
import PropTypes from 'prop-types';
import { ImageUploader } from './ImageUploader';
import { WysiwygToolbar } from './WysiwygToolbar';
import { MarkdownToolbar, Link, ButtonNew as Button } from '@crayons';
import HelpIcon from '@images/help.svg';

export const Toolbar = ({
  version,
  textAreaId,
  mode = 'markdown',
  onModeChange,
  wysiwygEnabled = false,
  wysiwygToolbarProps = {},
}) => {
  const showWysiwyg = wysiwygEnabled && version === 'v2';

  const handleModeSwitch = (nextMode) => {
    if (!showWysiwyg || mode === nextMode) {
      return;
    }

    onModeChange?.(nextMode);
  };

  const helpLink = (
    <Link
      key="help-link"
      block
      href="/p/editor_guide"
      target="_blank"
      rel="noopener noreferrer"
      icon={HelpIcon}
      aria-label="Help"
    />
  );

  const renderToolbar = () => {
    if (showWysiwyg && mode === 'wysiwyg') {
      return <WysiwygToolbar additionalItems={[helpLink]} {...wysiwygToolbarProps} />;
    }

    if (version === 'v1') {
      return <ImageUploader editorVersion={version} />;
    }

    return (
      <MarkdownToolbar
        textAreaId={textAreaId}
        additionalSecondaryToolbarElements={[helpLink]}
      />
    );
  };

  return (
    <div
      className={`crayons-article-form__toolbar ${
        version === 'v1' ? 'border-t-0' : ''
      }`}
    >
      {renderToolbar()}
      {showWysiwyg && (
        <div className="editor-mode-toggle" role="group" aria-label="Editor mode toggle">
          <Button
            variant={mode === 'markdown' ? 'primary' : 'secondary'}
            aria-pressed={mode === 'markdown'}
            onClick={() => handleModeSwitch('markdown')}
          >
            Markdown
          </Button>
          <Button
            variant={mode === 'wysiwyg' ? 'primary' : 'secondary'}
            aria-pressed={mode === 'wysiwyg'}
            onClick={() => handleModeSwitch('wysiwyg')}
            disabled={!wysiwygToolbarProps?.editor}
          >
            Visual
          </Button>
        </div>
      )}
    </div>
  );
};

Toolbar.propTypes = {
  version: PropTypes.string.isRequired,
  textAreaId: PropTypes.string.isRequired,
  mode: PropTypes.oneOf(['markdown', 'wysiwyg']),
  onModeChange: PropTypes.func,
  wysiwygEnabled: PropTypes.bool,
  wysiwygToolbarProps: PropTypes.shape({
    editor: PropTypes.object,
    onImageUploadStart: PropTypes.func,
    onImageUploadSuccess: PropTypes.func,
    onImageUploadError: PropTypes.func,
    onVideoUploadStart: PropTypes.func,
    onVideoUploadSuccess: PropTypes.func,
    onVideoUploadError: PropTypes.func,
    videoEnabled: PropTypes.bool,
  }),
};

Toolbar.displayName = 'Toolbar';
