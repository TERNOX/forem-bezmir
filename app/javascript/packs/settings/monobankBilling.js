import { initMonobankCardForms } from '../../settings/monobank/cardForm';

const READY_EVENTS = ['DOMContentLoaded', 'turbo:load', 'turbolinks:load'];

function initialize() {
  initMonobankCardForms();
}

READY_EVENTS.forEach((eventName) => {
  document.addEventListener(eventName, initialize, { once: eventName === 'DOMContentLoaded' });
});
