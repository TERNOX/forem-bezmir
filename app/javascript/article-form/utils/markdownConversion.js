let markdownItInstance = null;

const escapeHtml = (value) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const getMarkdownIt = () => {
  if (typeof window === 'undefined') {
    return null;
  }

  if (!markdownItInstance && typeof window.markdownit === 'function') {
    markdownItInstance = window.markdownit({ html: true, breaks: true, linkify: true });
  }

  return markdownItInstance;
};

export const markdownToHtml = (markdown = '') => {
  if (!markdown) {
    return '';
  }

  const md = getMarkdownIt();

  if (md) {
    return md.render(markdown);
  }

  const safe = escapeHtml(markdown);
  const paragraphs = safe.split(/\n{2,}/).map((block) => `<p>${block.replace(/\n/g, '<br>')}</p>`);

  return paragraphs.join('');
};

const ESCAPED_CHARACTERS = /[\\`*_{}\[\]()#+.!]/g;

const escapeText = (value) => value.replace(/\u00a0/g, ' ').replace(ESCAPED_CHARACTERS, '\\$&');

const wrapCode = (value) => {
  if (!value) {
    return '``';
  }

  const fence = value.includes('`') ? '``' : '`';
  return `${fence}${value}${fence}`;
};

const applyMarks = (value, marks = []) => {
  if (!marks || marks.length === 0) {
    return value;
  }

  return marks.reduceRight((acc, mark) => {
    if (!mark || !mark.type) {
      return acc;
    }

    switch (mark.type) {
      case 'bold':
        return `**${acc}**`;
      case 'italic':
        return `_${acc}_`;
      case 'strike':
        return `~~${acc}~~`;
      case 'code':
        return wrapCode(acc);
      case 'link': {
        const href = mark.attrs?.href || '';
        const title = mark.attrs?.title ? ` "${mark.attrs.title}"` : '';
        return `[${acc}](${href}${title})`;
      }
      default:
        return acc;
    }
  }, value);
};

const serializeInline = (nodes = [], context) =>
  nodes
    .map((node) => serializeNode(node, context))
    .join('')
    .replace(/\s+$/g, '');

const serializeListItem = (node, context, index) => {
  const stack = context.listStack || [];
  const current = stack[stack.length - 1];
  const indentLevel = Math.max(stack.length - 1, 0);
  const start = current?.counter ?? 1;
  const marker = current?.type === 'ordered' ? `${start + index}. ` : '- ';

  const childContext = {
    ...context,
    listStack: stack,
    insideListItem: true,
  };

  const content = (node.content || []).map((child) => serializeNode(child, childContext)).join('').trimEnd();

  const normalized = content
    .split('\n')
    .map((line, lineIndex) =>
      lineIndex === 0
        ? `${'  '.repeat(indentLevel)}${marker}${line}`
        : `${'  '.repeat(indentLevel + 1)}${line}`,
    )
    .join('\n');

  return `${normalized}\n`;
};

const serializeList = (node, context, type) => {
  const stack = context.listStack || [];
  const counterStart = type === 'ordered' ? node.attrs?.start || 1 : 1;
  const nextContext = {
    ...context,
    listStack: [...stack, { type, counter: counterStart }],
  };

  const items = (node.content || []).map((child, index) => serializeListItem(child, nextContext, index)).join('');
  const trailingNewline = stack.length === 0 ? '\n' : '';

  return `${items}${trailingNewline}`;
};

const serializeBlockquote = (node, context) => {
  const depth = (context.blockquoteDepth || 0) + 1;
  const childContext = { ...context, blockquoteDepth: depth };
  const content = (node.content || []).map((child) => serializeNode(child, childContext)).join('').trimEnd();
  const lines = content.split('\n');
  const prefix = `${'>'.repeat(depth)} `;
  return `${lines.map((line) => `${prefix}${line}`.trimEnd()).join('\n')}\n\n`;
};

const serializeCodeBlock = (node) => {
  const language = node.attrs?.language || '';
  const inner = (node.content || [])
    .map((child) => (child.type === 'text' ? child.text || '' : ''))
    .join('');

  return `\n\`\`\`${language ? `${language}` : ''}\n${inner}\n\`\`\`\n\n`;
};

const serializeNode = (node, context) => {
  if (!node) {
    return '';
  }

  switch (node.type) {
    case 'doc':
      return (node.content || [])
        .map((child) => serializeNode(child, context))
        .join('')
        .replace(/\s+$/g, '');
    case 'paragraph': {
      const text = serializeInline(node.content || [], context).trimEnd();
      if (!text && context.insideListItem) {
        return '';
      }
      const suffix = context.insideListItem || context.listStack?.length > 0 || context.blockquoteDepth
        ? '\n'
        : '\n\n';
      return `${text}${suffix}`;
    }
    case 'heading': {
      const level = Math.min(Math.max(node.attrs?.level || 1, 1), 6);
      const text = serializeInline(node.content || [], context).trim();
      return `${'#'.repeat(level)} ${text}\n\n`;
    }
    case 'bulletList':
      return serializeList(node, context, 'bullet');
    case 'orderedList':
      return serializeList(node, context, 'ordered');
    case 'blockquote':
      return serializeBlockquote(node, context);
    case 'horizontalRule':
      return `---\n\n`;
    case 'codeBlock':
      return serializeCodeBlock(node);
    case 'hardBreak':
      return '  \n';
    case 'text': {
      const text = escapeText(node.text || '');
      return applyMarks(text, node.marks, context);
    }
    default:
      return (node.content || []).map((child) => serializeNode(child, context)).join('');
  }
};

export const docToMarkdown = (doc) => {
  if (!doc || doc.type !== 'doc') {
    return '';
  }

  const context = { listStack: [], blockquoteDepth: 0, insideListItem: false };
  const markdown = serializeNode(doc, context)
    .replace(/\n{3,}/g, '\n\n')
    .replace(/\s+$/g, '');

  return markdown;
};

