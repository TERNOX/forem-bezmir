import { h, render } from 'preact';
import { VotingApp } from '../voting/VotingApp';

// Fork-only: mounts the community voting app on /vote/:slug (and top-level votings).
function loadVoting() {
  const root = document.getElementById('voting-app');
  if (!root || root.dataset.mounted) return;

  const payload = JSON.parse(root.dataset.voting);
  root.dataset.mounted = 'true';
  root.innerHTML = '';
  render(
    <VotingApp
      voting={payload.voting}
      categories={payload.categories}
      results={payload.results}
      strings={payload.strings}
      signInUrl={payload.signInUrl}
    />,
    root,
  );
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', loadVoting);
} else {
  loadVoting();
}
window.InstantClick?.on('change', loadVoting);
