import { h } from 'preact';
import PropTypes from 'prop-types';
import { useEffect, useMemo, useRef } from 'preact/hooks';
import { EditorContent, useEditor } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Link from '@tiptap/extension-link';
import Image from '@tiptap/extension-image';
import Placeholder from '@tiptap/extension-placeholder';
import Markdown from '@tiptap/extension-markdown';
import { locale } from '@utilities/locale';

export const WysiwygEditor = ({
  markdown,
  onMarkdownChange,
  onEditorReady,
  switchHelpContext,
}) => {
  const placeholder = useMemo(() => locale('core.editor_body_placeholder'), []);

  const skipNextUpdateRef = useRef(true);
  const lastAppliedMarkdownRef = useRef(markdown || '');

  const editor = useEditor({
    extensions: [
      StarterKit,
      Link.configure({ openOnClick: false }),
      Image,
      Placeholder.configure({ placeholder }),
      Markdown.configure({ html: true }),
    ],
    content: markdown || '',
    onUpdate({ editor: instance }) {
      const nextMarkdown = instance.storage.markdown.getMarkdown();
      if (skipNextUpdateRef.current && nextMarkdown === lastAppliedMarkdownRef.current) {
        skipNextUpdateRef.current = false;
        return;
      }

      skipNextUpdateRef.current = false;
      lastAppliedMarkdownRef.current = nextMarkdown;
      onMarkdownChange(nextMarkdown);
    },
  });

  useEffect(() => {
    if (!editor) {
      return undefined;
    }

    onEditorReady?.(editor);

    return () => {
      onEditorReady?.(null);
    };
  }, [editor, onEditorReady]);

  useEffect(() => {
    if (!editor) {
      return;
    }

    const nextValue = markdown || '';
    const currentMarkdown = editor.storage.markdown.getMarkdown();

    if (currentMarkdown !== nextValue) {
      skipNextUpdateRef.current = true;
      lastAppliedMarkdownRef.current = nextValue;
      editor.commands.setMarkdown(nextValue);
      return;
    }

    lastAppliedMarkdownRef.current = currentMarkdown;
  }, [editor, markdown]);

  if (!editor) {
    return null;
  }

  return (
    <div className="crayons-article-form__wysiwyg-wrapper">
      <EditorContent
        editor={editor}
        className="crayons-article-form__wysiwyg tiptap"
        id="article_body_wysiwyg"
        aria-label="Post Content"
        onFocus={(event) => switchHelpContext?.(event, 'article_body_markdown')}
      />
    </div>
  );
};

WysiwygEditor.propTypes = {
  markdown: PropTypes.string.isRequired,
  onMarkdownChange: PropTypes.func.isRequired,
  onEditorReady: PropTypes.func.isRequired,
  switchHelpContext: PropTypes.func.isRequired,
};

WysiwygEditor.displayName = 'WysiwygEditor';
