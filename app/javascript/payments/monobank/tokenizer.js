const CARD_FIELD_SELECTORS = {
  number: '[data-monobank-card-number]',
  expMonth: '[data-monobank-card-exp-month]',
  expYear: '[data-monobank-card-exp-year]',
  cvv: '[data-monobank-card-cvv]',
};

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content;
}

export function extractCardData(container) {
  if (!container) return null;

  const number = container.querySelector(CARD_FIELD_SELECTORS.number)?.value?.trim();
  const expMonth = container.querySelector(CARD_FIELD_SELECTORS.expMonth)?.value?.trim();
  const expYear = container.querySelector(CARD_FIELD_SELECTORS.expYear)?.value?.trim();
  const cvv = container.querySelector(CARD_FIELD_SELECTORS.cvv)?.value?.trim();

  if (!number || !expMonth || !expYear || !cvv) {
    return null;
  }

  return {
    number,
    exp_month: expMonth,
    exp_year: expYear,
    cvv,
  };
}

export async function requestCardToken(endpoint, card) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken(),
    },
    body: JSON.stringify({ card }),
    credentials: 'same-origin',
  });

  const payload = await response.json().catch(() => ({}));

  if (!response.ok || !payload.token) {
    const error = payload.error || 'Unable to tokenize card. Please try again.';
    throw new Error(error);
  }

  return payload.token;
}
