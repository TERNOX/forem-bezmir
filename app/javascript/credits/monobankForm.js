import { extractCardData, requestCardToken } from '../payments/monobank/tokenizer';

function changeSubmitButton(button, { active, label }) {
  if (!button) return;

  button.disabled = !active;
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

function getAmount() {
  const value = Number(document.getElementById('amount-input')?.value || 0);
  let pricePer = 0;
  if (value < 10) {
    pricePer = 5;
  } else if (value < 100) {
    pricePer = 4;
  } else if (value < 1000) {
    pricePer = 3;
  } else {
    pricePer = 2.5;
  }

  return { value: value * pricePer, pricePer };
}

function calculatePriceAndShow() {
  setTimeout(() => {
    const calculated = document.getElementById('calculated-price');
    if (!calculated) return;
    const { value, pricePer } = getAmount();
    calculated.innerHTML = `$${value} ($${pricePer}/each)`;
  }, 100);
}

function handleCreditPriceClick() {
  const els = document.getElementsByClassName('credit-price');
  Array.from(els).forEach((el) => {
    el.addEventListener('click', (event) => {
      const amountInput = document.getElementById('amount-input');
      if (!amountInput) return;
      amountInput.value = event.target.dataset.num;
      calculatePriceAndShow();
    });
  });
}

function listenForNumberChange() {
  const input = document.getElementById('amount-input');
  if (!input) return;

  input.addEventListener('keydown', (event) => {
    const keyCode = event.keyCode;
    if (
      (keyCode >= 48 && keyCode <= 57) ||
      (keyCode >= 96 && keyCode <= 105) ||
      keyCode === 8
    ) {
      calculatePriceAndShow();
    } else {
      event.preventDefault();
    }
  });
}

function shouldTokenize(cardFields, existingCardInputs) {
  if (!cardFields) return false;
  const hasExisting = existingCardInputs.length > 0;
  const hidden = cardFields.classList.contains('hidden');
  return !hasExisting || !hidden;
}

export function initMonobankCreditForm() {
  const form = document.querySelector('[data-monobank-credit-form]');
  if (!form) return;

  const submitButton = document.getElementById('add-credit-card-button');
  const cardFields = form.querySelector('[data-monobank-card-fields]');
  const addNewCardButton = form.querySelector('[data-monobank-add-card]');
  const existingCardInputs = form.querySelectorAll('[data-monobank-existing-card]');
  const errorContainer = form.querySelector('[data-monobank-error]');
  const dataset = form.dataset;

  if (addNewCardButton && cardFields) {
    addNewCardButton.addEventListener('click', (event) => {
      event.preventDefault();
      cardFields.classList.remove('hidden');
      existingCardInputs.forEach((input) => {
        input.checked = false;
      });
    });
  }

  existingCardInputs.forEach((input) => {
    input.addEventListener('change', () => {
      if (cardFields) {
        cardFields.classList.add('hidden');
      }
      const paymentToken = document.getElementById('monobank-payment-token');
      if (paymentToken) {
        paymentToken.value = '';
      }
    });
  });

  form.addEventListener('submit', async (event) => {
    if (!shouldTokenize(cardFields, existingCardInputs)) {
      changeSubmitButton(submitButton, { active: false, label: dataset.monobankSubmittingLabel });
      return;
    }

    event.preventDefault();
    const cardData = extractCardData(cardFields);
    if (!cardData) {
      showError(errorContainer, dataset.monobankIncompleteMessage);
      return;
    }

    try {
      showError(errorContainer, '');
      changeSubmitButton(submitButton, { active: false, label: dataset.monobankSubmittingLabel });
      const token = await requestCardToken(dataset.monobankTokenEndpoint, cardData);
      const tokenField = document.getElementById('monobank-payment-token');
      if (tokenField) {
        tokenField.value = token;
      }
      changeSubmitButton(submitButton, { active: false, label: dataset.monobankSubmittingLabel });
      form.submit();
    } catch (error) {
      changeSubmitButton(submitButton, { active: true, label: dataset.monobankSubmitLabel });
      showError(errorContainer, error.message || dataset.monobankErrorMessage);
    }
  });

  form.addEventListener('ajax:complete', () => {
    changeSubmitButton(submitButton, { active: true, label: dataset.monobankSubmitLabel });
  });

  handleCreditPriceClick();
  listenForNumberChange();
  calculatePriceAndShow();
}
