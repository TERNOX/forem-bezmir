import { Controller } from '@hotwired/stimulus';

// Fork-only: game search + "add as nominee" for the admin voting page.
// Searches the local catalog and IGDB (via Admin::GamesController#search) and
// posts the picked game to Admin::VotingNomineesController#create.
export default class VotingNomineePickerController extends Controller {
  static targets = ['input', 'results', 'status'];
  static values = { searchUrl: String, createUrl: String };

  connect() {
    this.timer = null;
    this.requestId = 0;
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  search() {
    clearTimeout(this.timer);
    const query = this.inputTarget.value.trim();
    if (query.length < 2) {
      this.clearResults();
      return;
    }
    this.timer = setTimeout(() => this.fetchResults(query), 300);
  }

  clear() {
    this.inputTarget.value = '';
    this.clearResults();
  }

  clearResults() {
    this.resultsTarget.innerHTML = '';
    this.statusTarget.textContent = '';
  }

  async fetchResults(query) {
    const requestId = ++this.requestId;
    this.statusTarget.textContent = 'Searching…';
    try {
      const url = new URL(this.searchUrlValue, window.location.origin);
      url.searchParams.set('q', query);
      const response = await fetch(url, {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      });
      const data = await response.json();
      if (requestId !== this.requestId) return;
      this.render(data);
    } catch (error) {
      if (requestId === this.requestId) {
        this.statusTarget.textContent = `Search failed: ${error.message}`;
      }
    }
  }

  render(data) {
    const items = [
      ...data.local.map((game) => ({ ...game, source: 'catalog' })),
      ...data.igdb.map((game) => ({ ...game, source: 'igdb' })),
    ];
    let status = items.length ? '' : 'Nothing found.';
    if (!data.igdb_configured)
      status += ' IGDB is not configured — only the catalog was searched.';
    if (data.error) status += ` IGDB error: ${data.error}`;
    this.statusTarget.textContent = status.trim();

    this.resultsTarget.innerHTML = '';
    items.forEach((game) =>
      this.resultsTarget.appendChild(this.buildItem(game)),
    );
  }

  buildItem(game) {
    const li = document.createElement('li');
    li.className = 'voting-admin-picker__item';

    if (game.cover_url) {
      const img = document.createElement('img');
      img.src = game.cover_url;
      img.alt = '';
      img.loading = 'lazy';
      li.appendChild(img);
    } else {
      const placeholder = document.createElement('span');
      placeholder.className = 'voting-admin-picker__noimg';
      li.appendChild(placeholder);
    }

    const meta = document.createElement('div');
    meta.className = 'voting-admin-picker__meta';
    const title = document.createElement('strong');
    title.className = 'fs-s';
    title.textContent = game.title;
    const details = document.createElement('span');
    details.className = 'fs-xs color-base-60';
    details.textContent = [
      game.release_year,
      (game.platforms || []).slice(0, 4).join(', '),
      game.source === 'catalog' ? 'in catalog' : 'IGDB',
    ]
      .filter(Boolean)
      .join(' · ');
    meta.append(title, details);
    li.appendChild(meta);

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'crayons-btn crayons-btn--s';
    button.textContent = 'Add';
    button.addEventListener('click', () => this.add(game, button));
    li.appendChild(button);
    return li;
  }

  async add(game, button) {
    button.disabled = true;
    button.textContent = 'Adding…';
    const body = new FormData();
    if (game.source === 'catalog') {
      body.append('game_id', game.id);
    } else {
      body.append('igdb_id', game.igdb_id);
    }
    try {
      const response = await fetch(this.createUrlValue, {
        method: 'POST',
        body,
        credentials: 'same-origin',
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')
            ?.content,
        },
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || response.statusText);
      window.location.reload();
    } catch (error) {
      button.disabled = false;
      button.textContent = 'Add';
      this.statusTarget.textContent = error.message;
    }
  }
}
