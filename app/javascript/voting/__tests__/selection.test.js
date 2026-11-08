import {
  fromBallot,
  interpolate,
  isAnswered,
  pruneSelections,
  sameSelections,
  setOther,
  toggleNominee,
  toPayload,
} from '../selection';

describe('pruneSelections', () => {
  const categories = [
    {
      id: 1,
      maxChoices: 2,
      allowOther: false,
      nominees: [{ id: 10 }, { id: 11 }],
    },
    { id: 2, maxChoices: 1, allowOther: true, nominees: [{ id: 20 }] },
  ];

  it('drops nominees and nominations that no longer exist', () => {
    const draft = {
      1: { ids: [99, 10], other: 'stale' },
      7: { ids: [70], other: '' },
    };
    expect(pruneSelections(draft, categories)).toEqual({
      1: { ids: [10], other: '' },
    });
  });

  it('respects a lowered limit, counting the free-text answer', () => {
    expect(
      pruneSelections({ 2: { ids: [20], other: 'Mine' } }, categories),
    ).toEqual({ 2: { ids: [], other: 'Mine' } });
    expect(pruneSelections({ 1: { ids: [10, 11, 10] } }, categories)).toEqual({
      1: { ids: [10, 11], other: '' },
    });
  });

  it('ignores malformed drafts', () => {
    expect(pruneSelections(null, categories)).toEqual({});
    expect(pruneSelections('x', categories)).toEqual({});
    expect(pruneSelections({ 1: { ids: 'x' } }, categories)).toEqual({
      1: { ids: [], other: '' },
    });
  });
});

const single = { maxChoices: 1, ranked: false };
const multi = { maxChoices: 2, ranked: false };
const ranked = { maxChoices: 3, ranked: true };

describe('voting selection helpers', () => {
  it('behaves like a radio for single-choice nominations', () => {
    let { selection } = toggleNominee(single, undefined, 1);
    ({ selection } = toggleNominee(single, selection, 2));
    expect(selection).toEqual({ ids: [2], other: '' });
  });

  it('stops at maxChoices and reports it', () => {
    let { selection } = toggleNominee(multi, undefined, 1);
    ({ selection } = toggleNominee(multi, selection, 2));
    const result = toggleNominee(multi, selection, 3);
    expect(result.limitReached).toBe(true);
    expect(result.selection.ids).toEqual([1, 2]);
  });

  it('counts the other answer as a pick', () => {
    let selection = setOther(multi, { ids: [1], other: '' }, 'Steam Deck');
    const result = toggleNominee(multi, selection, 2);
    expect(result.limitReached).toBe(true);
    selection = setOther(single, { ids: [1], other: '' }, 'Мій варіант');
    expect(selection).toEqual({ ids: [], other: 'Мій варіант' });
  });

  it('keeps ranked picks in place order and shifts when one is removed', () => {
    let { selection } = toggleNominee(ranked, undefined, 10);
    ({ selection } = toggleNominee(ranked, selection, 20));
    ({ selection } = toggleNominee(ranked, selection, 30));
    ({ selection } = toggleNominee(ranked, selection, 10));
    expect(selection.ids).toEqual([20, 30]);
  });

  it('converts to and from the server format', () => {
    const selections = fromBallot({
      selections: {
        5: { nominee_ids: [3, 1], other: 'x' },
        6: { nominee_ids: [] },
      },
    });
    expect(selections['5']).toEqual({ ids: [3, 1], other: 'x' });
    expect(isAnswered(selections['6'])).toBe(false);
    expect(toPayload(selections)).toEqual({
      5: { nominee_ids: [3, 1], other: 'x' },
    });
    expect(
      sameSelections(selections, { 5: { ids: [3, 1], other: 'x ' } }),
    ).toBe(true);
  });

  it('interpolates %{} placeholders', () => {
    expect(interpolate('Обрано: %{count} з %{max}', { count: 1, max: 3 })).toBe(
      'Обрано: 1 з 3',
    );
  });
});
