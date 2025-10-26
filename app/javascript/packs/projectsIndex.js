import { debounceAction } from '../utilities/debounceAction';

function parseSort(select) {
  if (!select) {
    return { field: 'created_at', direction: 'desc' };
  }

  const [field, direction] = select.value.split('-');
  return {
    field: field || 'created_at',
    direction: direction || 'desc',
  };
}

function numericValue(card, key) {
  if (key === 'created_at') {
    return Number(card.dataset.createdAt);
  }

  if (key === 'articles_count') {
    return Number(card.dataset.articlesCount);
  }

  return 0;
}

function formatCount(count, labels) {
  if (!labels) {
    return '';
  }

  if (count === 0 && labels.zero) {
    return labels.zero;
  }

  if (count === 1 && labels.one) {
    return labels.one.replace('%{count}', count);
  }

  if (labels.two && count === 2) {
    return labels.two.replace('%{count}', count);
  }

  const mod10 = count % 10;
  const mod100 = count % 100;

  if (
    labels.few &&
    mod10 >= 2 &&
    mod10 <= 4 &&
    (mod100 < 12 || mod100 > 14)
  ) {
    return labels.few.replace('%{count}', count);
  }

  if (
    labels.many &&
    (mod10 === 0 || mod10 >= 5 || (mod100 >= 11 && mod100 <= 14))
  ) {
    return labels.many.replace('%{count}', count);
  }

  if (labels.other) {
    return labels.other.replace('%{count}', count);
  }

  return '';
}

function updateCountSummary(summaryElement, visibleCount, labels) {
  if (!summaryElement) {
    return;
  }

  if (!labels) {
    summaryElement.textContent = visibleCount;
    return;
  }

  summaryElement.textContent = formatCount(visibleCount, labels);
}

function initializeProjectsPage() {
  const grid = document.querySelector('[data-projects-grid]');

  if (!grid || grid.dataset.projectsInitialized === 'true') {
    return;
  }

  grid.dataset.projectsInitialized = 'true';

  const searchInput = document.querySelector('[data-projects-search]');
  const sortSelect = document.querySelector('[data-projects-sort]');
  const emptyMessage = document.querySelector('[data-projects-empty]');
  const summaryElement = document.querySelector('[data-projects-summary]');
  let countLabels;

  if (summaryElement && summaryElement.dataset.countLabels) {
    try {
      countLabels = JSON.parse(summaryElement.dataset.countLabels);
    } catch (error) {
      countLabels = undefined;
    }
  }

  let cards = Array.from(grid.querySelectorAll('[data-project-card]'));

  const sortCards = () => {
    const { field, direction } = parseSort(sortSelect);
    const sortedCards = [...cards].sort((cardA, cardB) => {
      const valueA = numericValue(cardA, field);
      const valueB = numericValue(cardB, field);

      if (valueA !== valueB) {
        return direction === 'asc' ? valueA - valueB : valueB - valueA;
      }

      const nameA = cardA.dataset.name || '';
      const nameB = cardB.dataset.name || '';
      return nameA.localeCompare(nameB);
    });

    sortedCards.forEach((card) => {
      grid.appendChild(card);
    });

    cards = sortedCards;
  };

  const applyFilters = () => {
    const query = (searchInput?.value || '').trim().toLowerCase();
    let visibleCount = 0;

    cards.forEach((card) => {
      const text = card.dataset.searchable || '';
      const matches = !query || text.includes(query);
      card.classList.toggle('projects-card--hidden', !matches);
      card.toggleAttribute('hidden', !matches);
      card.setAttribute('aria-hidden', matches ? 'false' : 'true');
      if (matches) {
        visibleCount += 1;
      }
    });

    if (emptyMessage) {
      if (visibleCount === 0) {
        emptyMessage.removeAttribute('hidden');
      } else {
        emptyMessage.setAttribute('hidden', 'hidden');
      }
    }

    updateCountSummary(summaryElement, visibleCount, countLabels);
  };

  const debouncedFilter = debounceAction(() => {
    sortCards();
    applyFilters();
  }, { time: 120 });

  if (searchInput) {
    searchInput.addEventListener('input', debouncedFilter);
  }

  if (sortSelect) {
    sortSelect.addEventListener('change', () => {
      sortCards();
      applyFilters();
    });
  }

  sortCards();
  applyFilters();
}

const initializeEvents = ['DOMContentLoaded', 'turbo:load'];

initializeEvents.forEach((eventName) => {
  document.addEventListener(eventName, initializeProjectsPage);
});

if (document.readyState !== 'loading') {
  initializeProjectsPage();
}
