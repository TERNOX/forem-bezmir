import { h } from 'preact';
import PropTypes from 'prop-types';
import { ImageUploader } from './ImageUploader';
import { MarkdownToolbar, Link } from '@crayons';
import HelpIcon from '@images/help.svg';
import AgentSessionIcon from '@images/agent-session.svg';

export const Toolbar = ({ version, textAreaId }) => {
  return (
    <div
      className={`crayons-article-form__toolbar ${
        version === 'v1' ? 'border-t-0' : ''
      }`}
    >
      {version === 'v1' ? (
        <div className="flex items-center">
          <ImageUploader editorVersion={version} />
          <a
            href="/agent_sessions/new"
            target="_blank"
            rel="noopener noreferrer"
            className="c-btn ml-2"
            title="Upload Agent Session"
          >
            Agent Session
          </a>
        </div>
      ) : (
        <MarkdownToolbar
          textAreaId={textAreaId}
          additionalPrimaryToolbarElements={[
            <Link
              key="agent-session-link"
              href="/agent_sessions/new"
              target="_blank"
              rel="noopener noreferrer"
              icon={AgentSessionIcon}
              aria-label="Upload Agent Session"
              title="Upload Agent Session"
            />,
          ]}
          additionalSecondaryToolbarElements={[
            <Link
              key="help-link"
              block
              href="/p/editor_guide"
              target="_blank"
              rel="noopener noreferrer"
              icon={HelpIcon}
              aria-label="Help"
            />,
          ]}
        />
      )}
    </div>
  );
};

Toolbar.propTypes = {
  version: PropTypes.string.isRequired,
};

Toolbar.displayName = 'Toolbar';
