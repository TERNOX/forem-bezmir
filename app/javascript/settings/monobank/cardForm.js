import { extractCardData, requestCardToken } from '../../payments/monobank/tokenizer';

function setButtonState(button, { disabled, label }) {
  if (!button) return;

  button.disabled = disabled;
  if (label) {
    button.dataset.originalLabel = button.dataset.originalLabel || button.textContent;
    button.textContent = label;
  } else if (button.dataset.originalLabel) {
    button.textContent = button.dataset.originalLabel;
  }
}

function showError(container, message) {
  if (!container) return;
  container.textContent = message;
}

async function handleSubmit(event) {
  const form = event.currentTarget;
  const tokenEndpoint = form.dataset.monobankTokenEndpoint;
  const targetField = form.dataset.monobankTargetField || 'stripe_token';
  const errorContainer = form.querySelector('[data-monobank-error]');
  const submitButton = form.querySelector('[data-monobank-submit]');
  const cardFields = form.querySelector('[data-monobank-card-fields]');
  const submittingLabel = form.dataset.monobankSubmittingLabel;
  const successLabel = form.dataset.monobankSuccessLabel;

  if (!tokenEndpoint || !cardFields) {
    return;
  }

  event.preventDefault();

  const cardData = extractCardData(cardFields);
  if (!cardData) {
    showError(errorContainer, form.dataset.monobankIncompleteMessage || 'Please complete all card fields.');
    return;
  }

  try {
    showError(errorContainer, '');
    setButtonState(submitButton, { disabled: true, label: submittingLabel });

    const token = await requestCardToken(tokenEndpoint, cardData);

    let hidden = form.querySelector(`input[name="${targetField}"]`);
    if (!hidden) {
      hidden = document.createElement('input');
      hidden.type = 'hidden';
      hidden.name = targetField;
      form.appendChild(hidden);
    }
    hidden.value = token;

    setButtonState(submitButton, { disabled: false, label: successLabel });
    form.submit();
  } catch (error) {
    setButtonState(submitButton, { disabled: false });
    showError(errorContainer, error.message || form.dataset.monobankErrorMessage);
  }
}

export function initMonobankCardForms() {
  const forms = document.querySelectorAll('[data-monobank-card-form]');

  forms.forEach((form) => {
    if (form.dataset.monobankFormBound) return;
    form.dataset.monobankFormBound = 'true';
    form.addEventListener('submit', handleSubmit);
  });
}
