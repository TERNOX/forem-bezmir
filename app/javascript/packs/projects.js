import { debounceAction } from '../utilities/debounceAction';

const initializeProjectsSearch = () => {
  const form = document.querySelector('[data-projects-search-form]');

  if (!form || form.dataset.projectsSearchReady === 'true') {
    return;
  }

  const input = form.querySelector('input[name="q"]');
  const select = form.querySelector('select[name="sort"]');
  const submitForm = () => form.requestSubmit();
  const debouncedSubmit = debounceAction(submitForm, { time: 250 });

  if (input) {
    input.addEventListener('input', () => {
      debouncedSubmit();
    });
  }

  if (select) {
    select.addEventListener('change', submitForm);
  }

  form.addEventListener('submit', () => {
    if (input) {
      input.blur();
    }
  });

  form.dataset.projectsSearchReady = 'true';
};

const readyEvents = ['DOMContentLoaded', 'turbo:load', 'turbo:render', 'page:load'];
readyEvents.forEach((eventName) => {
  document.addEventListener(eventName, initializeProjectsSearch);
});
