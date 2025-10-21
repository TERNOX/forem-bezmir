import { h, render } from 'preact';
import { ProjectsDirectory } from '../projects/ProjectsDirectory';

function initializeProjectsDirectory() {
  const root = document.getElementById('projects-directory-root');
  if (!root || root.dataset.initialized === 'true') {
    return;
  }

  const initialProjects = JSON.parse(root.dataset.initialProjects || '[]');
  const meta = JSON.parse(root.dataset.meta || '{}');
  const { perPage, initialQuery, initialSort } = root.dataset;

  render(
    <ProjectsDirectory
      initialProjects={initialProjects}
      initialMeta={meta}
      perPage={perPage}
      initialQuery={initialQuery}
      initialSort={initialSort}
    />,
    root,
  );

  root.dataset.initialized = 'true';
}

if (window.InstantClick) {
  window.InstantClick.on('change', () => {
    initializeProjectsDirectory();
  });
}

initializeProjectsDirectory();
