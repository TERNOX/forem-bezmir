import { initializeDropdown } from '@utilities/dropdownUtils';

function initDropdown() {
  const profileDropdownDiv = document.querySelector('.profile-dropdown');

  if (profileDropdownDiv.dataset.dropdownInitialized === 'true') {
    return;
  }

  if (!profileDropdownDiv) {
    return;
  }

  initializeDropdown({
    triggerElementId: 'organization-profile-dropdown',
    dropdownContentId: 'organization-profile-dropdownmenu',
  });

  // Add actual link location (SEO doesn't like these "useless" links, so adding in here instead of in HTML)
  const reportAbuseLink = profileDropdownDiv.querySelector(
    '.report-abuse-link-wrapper',
  );
  if (reportAbuseLink) {
    const reportLabel = reportAbuseLink.dataset.label || 'Report Abuse';
    reportAbuseLink.innerHTML = `<a href="${reportAbuseLink.dataset.path}" class="crayons-link crayons-link--block">${reportLabel}</a>`;
  }

  const adminSettingsLink = profileDropdownDiv.querySelector(
    '.organization-admin-link-wrapper',
  );

  if (adminSettingsLink) {
    const adminLabel = adminSettingsLink.dataset.label || 'Admin settings';
    adminSettingsLink.innerHTML = `<a href="${adminSettingsLink.dataset.path}" class="crayons-link crayons-link--block" data-no-instant>${adminLabel}</a>`;
  }

  profileDropdownDiv.dataset.dropdownInitialized = true;
}

initDropdown();
