import { initializeDropdown } from '@utilities/dropdownUtils';

initializeDropdown({
  triggerElementId: 'timeperiods-trigger',
  dropdownContentId: 'timeperiods-dropdown',
});

// Fetch and display stats
async function fetchStats({ period = 7, startDate = null, endDate = null } = {}) {
  try {
    const params = new URLSearchParams();
    if (startDate && endDate) {
      params.set('start_date', startDate);
      params.set('end_date', endDate);
    } else {
      params.set('period', period);
    }

    const response = await fetch(`/admin/stats?${params.toString()}`);
    const data = await response.json();
    updateStatsDisplay(data);
  } catch (error) {
    console.error('Error fetching stats:', error);
    showError();
  }
}

function updateStatsDisplay(data) {
  const statElements = {
    published_posts: document.querySelector('[data-stat="published_posts"]'),
    comments: document.querySelector('[data-stat="comments"]'),
    public_reactions: document.querySelector('[data-stat="public_reactions"]'),
    new_users: document.querySelector('[data-stat="new_users"]'),
  };

  Object.keys(statElements).forEach((key) => {
    if (statElements[key]) {
      statElements[key].textContent = data[key].toLocaleString();
    }
  });
}

function showError() {
  const container = document.getElementById('admin-stats-container');
  if (container) {
    container.innerHTML = '<div class="color-accent-danger">Error loading statistics. Please try again.</div>';
  }
}

// Handle period selector changes
document.addEventListener('DOMContentLoaded', () => {
  // Load initial stats
  fetchStats({ period: 7 });

  const customPeriodSelector = document.querySelector('.js-custom-period');
  const customFields = document.querySelector('.js-custom-period-fields');
  const customStartDate = document.getElementById('custom-start-date');
  const customEndDate = document.getElementById('custom-end-date');
  const customApply = document.getElementById('custom-period-apply');

  const toggleCustomFields = (show) => {
    if (!customFields) {
      return;
    }

    customFields.classList.toggle('hidden', !show);
    customFields.setAttribute('aria-hidden', (!show).toString());
  };

  // Add event listeners to period selectors
  const periodSelectors = document.querySelectorAll('.js-period-selector');
  periodSelectors.forEach((selector) => {
    selector.addEventListener('change', (e) => {
      const period = e.target.dataset.period;
      if (period === 'custom') {
        toggleCustomFields(true);
        return;
      }

      toggleCustomFields(false);
      fetchStats({ period });
    });
  });

  if (customStartDate && customEndDate) {
    customStartDate.addEventListener('change', () => {
      customEndDate.min = customStartDate.value;
    });
  }

  if (customApply) {
    customApply.addEventListener('click', () => {
      if (!customStartDate?.value || !customEndDate?.value) {
        return;
      }

      fetchStats({ startDate: customStartDate.value, endDate: customEndDate.value });
    });
  }

  toggleCustomFields(customPeriodSelector?.checked);
});
