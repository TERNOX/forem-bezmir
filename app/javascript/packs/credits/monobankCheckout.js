import { initMonobankCreditForm } from '../../credits/monobankForm';

const READY_EVENTS = ['DOMContentLoaded', 'turbo:load', 'turbolinks:load'];

function initialize() {
  initMonobankCreditForm();
}

READY_EVENTS.forEach((eventName) => {
  document.addEventListener(eventName, initialize, { once: eventName === 'DOMContentLoaded' });
});
