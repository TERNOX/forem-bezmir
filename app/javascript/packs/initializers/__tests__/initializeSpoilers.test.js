import { initializeSpoilers } from '../initializeSpoilers';

describe('initializeSpoilers', () => {
  let originalGetContext;

  beforeEach(() => {
    originalGetContext = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = jest.fn(() => ({
      font: '',
      measureText: jest.fn(() => ({ width: 50 })),
    }));
  });

  afterEach(() => {
    HTMLCanvasElement.prototype.getContext = originalGetContext;
    document.body.innerHTML = '';
  });

  it('toggles spoiler visibility on click and enter', () => {
    document.body.innerHTML =
      '<span data-spoiler="true" data-spoiler-label="Spoiler" aria-expanded="false"></span>';
    const spoiler = document.querySelector('[data-spoiler]');

    Object.defineProperty(spoiler, 'clientWidth', { value: 80, configurable: true });

    initializeSpoilers();

    expect(spoiler.getAttribute('aria-expanded')).toBe('false');

    spoiler.click();
    expect(spoiler.getAttribute('aria-expanded')).toBe('true');
    expect(spoiler.dataset.spoilerExpanded).toBe('true');

    const keydownEvent = new KeyboardEvent('keydown', { key: 'Enter', bubbles: true });
    spoiler.dispatchEvent(keydownEvent);

    expect(spoiler.getAttribute('aria-expanded')).toBe('false');
    expect(spoiler.dataset.spoilerExpanded).toBe('false');
  });

  it('hides the label when it cannot fit in the available space', () => {
    document.body.innerHTML =
      '<span data-spoiler="true" data-spoiler-label="Spoiler" aria-expanded="false" style="padding: 2px 4px"></span>';
    const spoiler = document.querySelector('[data-spoiler]');

    Object.defineProperty(spoiler, 'clientWidth', { value: 30, configurable: true });

    initializeSpoilers();

    expect(spoiler.dataset.spoilerLabelHidden).toBe('true');
  });

  it('keeps the label visible when width cannot be measured yet', () => {
    document.body.innerHTML =
      '<span data-spoiler="true" data-spoiler-label="Spoiler" aria-expanded="false" style="padding: 2px 4px"></span>';
    const spoiler = document.querySelector('[data-spoiler]');

    Object.defineProperty(spoiler, 'clientWidth', { value: 0, configurable: true });

    initializeSpoilers();

    expect(spoiler.dataset.spoilerLabelHidden).toBeUndefined();
  });
});
