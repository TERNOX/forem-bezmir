// Fork-only: pure helpers for the voting app's selection state.
// A selection is { ids: number[], other: string } per category id.

export const emptySelection = () => ({ ids: [], other: '' });

export function pickCount(selection) {
  if (!selection) return 0;
  return selection.ids.length + (selection.other.trim() ? 1 : 0);
}

export function isAnswered(selection) {
  return pickCount(selection) > 0;
}

export function isSingleChoice(category) {
  return category.maxChoices === 1 && !category.ranked;
}

/**
 * Toggles a nominee. Single-choice categories behave like radios; others stop
 * at maxChoices. For ranked categories the array order is the place order, so
 * removing a pick moves the later ones up.
 *
 * @returns {{ selection: object, limitReached: boolean }}
 */
export function toggleNominee(category, selection, nomineeId) {
  const current = selection || emptySelection();
  if (current.ids.includes(nomineeId)) {
    return {
      selection: {
        ...current,
        ids: current.ids.filter((id) => id !== nomineeId),
      },
      limitReached: false,
    };
  }
  if (isSingleChoice(category)) {
    return { selection: { ids: [nomineeId], other: '' }, limitReached: false };
  }
  if (pickCount(current) >= category.maxChoices) {
    return { selection: current, limitReached: true };
  }
  return {
    selection: { ...current, ids: [...current.ids, nomineeId] },
    limitReached: false,
  };
}

export function setOther(category, selection, text) {
  const current = selection || emptySelection();
  if (isSingleChoice(category) && text.trim()) {
    return { ids: [], other: text };
  }
  return { ...current, other: text };
}

/** Converts app state to the payload expected by VotingBallotsController#update. */
export function toPayload(selections) {
  const payload = {};
  Object.entries(selections).forEach(([categoryId, selection]) => {
    if (!isAnswered(selection)) return;
    payload[categoryId] = {
      nominee_ids: selection.ids,
      other: selection.other.trim(),
    };
  });
  return payload;
}

/** Converts the server ballot to app state. */
export function fromBallot(ballot) {
  const selections = {};
  if (!ballot) return selections;
  Object.entries(ballot.selections || {}).forEach(([categoryId, value]) => {
    selections[categoryId] = {
      ids: (value.nominee_ids || []).map(Number),
      other: value.other || '',
    };
  });
  return selections;
}

export function sameSelections(a, b) {
  return JSON.stringify(toPayload(a)) === JSON.stringify(toPayload(b));
}

export function interpolate(template, vars = {}) {
  return String(template || '').replace(/%\{(\w+)\}/g, (_, key) =>
    vars[key] === undefined ? '' : String(vars[key]),
  );
}
