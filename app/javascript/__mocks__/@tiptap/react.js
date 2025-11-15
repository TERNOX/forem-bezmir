import { h } from 'preact';
import { useMemo } from 'preact/hooks';

const createChain = (api) => ({
  focus: () => createChain(api),
  run: () => createChain(api),
  insertContent: () => createChain(api),
  setImage: () => createChain(api),
});

export const useEditor = (options = {}) => {
  const editor = useMemo(() => {
    const api = {
      _content: typeof options.content === 'string' ? options.content : '',
      getJSON: () => ({ type: 'doc', content: [] }),
      getHTML: () => api._content,
      commands: {
        setContent(value) {
          api._content = typeof value === 'string' ? value : '';
          if (typeof options.onUpdate === 'function') {
            options.onUpdate({ editor: api });
          }
          return api.commands;
        },
        focus: () => api.commands,
        run: () => api.commands,
        insertContent: () => api.commands,
        setImage: () => api.commands,
      },
      chain: () => createChain(api),
      view: { dom: typeof document !== 'undefined' ? document.createElement('div') : null },
    };

    return api;
  }, []);

  return editor;
};

export const EditorContent = ({ editor, ...props }) => (
  <div
    role="textbox"
    aria-multiline="true"
    contentEditable
    data-testid="tiptap-editor"
    {...props}
  />
);

export default { useEditor, EditorContent };
