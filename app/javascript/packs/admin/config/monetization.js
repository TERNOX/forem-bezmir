const READY_EVENTS = ['DOMContentLoaded', 'turbo:load', 'turbolinks:load'];

function toggleFields(select, fieldGroups) {
  const selected = select.value;

  fieldGroups.forEach((group) => {
    const provider = group.dataset.monetizationProviderFields;
    const isActive = provider === selected;

    group.classList.toggle('hidden', !isActive);

    group.querySelectorAll('input, select, textarea').forEach((input) => {
      input.disabled = !isActive;
    });
  });
}

function initialize() {
  const select = document.querySelector('[data-monetization-provider-select]');
  const fieldGroups = document.querySelectorAll('[data-monetization-provider-fields]');

  if (!select || fieldGroups.length === 0) {
    return;
  }

  toggleFields(select, fieldGroups);
  select.addEventListener('change', () => toggleFields(select, fieldGroups));
}

READY_EVENTS.forEach((eventName) => {
  document.addEventListener(eventName, initialize, { once: eventName === 'DOMContentLoaded' });
});
