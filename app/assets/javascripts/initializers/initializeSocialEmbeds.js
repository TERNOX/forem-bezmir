/* Fork-only: for each embedded social post (Twitter/X, Bluesky), ask our own
   liveness endpoint whether the original is gone; if so, swap the dead platform
   widget for the self-hosted archive card. If the article's markup already has a
   baked archive card we just reveal it; otherwise (capture failed at publish
   time) we inject the card HTML the endpoint returns. Live posts are left
   untouched. Safe to run repeatedly (InstantClick re-runs initializers). */
function initializeSocialEmbeds() {
  const embeds = document.querySelectorAll('.ltag-social-embed');
  if (!embeds.length) {
    return;
  }

  embeds.forEach((embed) => {
    if (embed.dataset.socialEmbedChecked === 'true') {
      return;
    }
    embed.dataset.socialEmbedChecked = 'true';

    // Already archived server-side (source was gone when the article rendered).
    if (embed.classList.contains('is-archived')) {
      return;
    }

    const platform = embed.dataset.platform;
    const sourceId = embed.dataset.sourceId;
    if (!platform || !sourceId) {
      return;
    }

    // Always request the current card HTML: a baked card may be stale or partial
    // (e.g. one photo failed at capture and was recovered later by a refresh), so
    // we replace it with the server-rendered card reflecting the latest snapshot.
    const url =
      '/social_embeds/status?platform=' +
      encodeURIComponent(platform) +
      '&source_id=' +
      encodeURIComponent(sourceId) +
      '&include_html=1';

    window
      .fetch(url, {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      })
      .then((response) => (response.ok ? response.json() : null))
      .then((data) => {
        if (!data || !data.archived) {
          return;
        }
        if (data.html) {
          const existing = embed.querySelector('.ltag-social-embed__archive');
          if (existing) {
            existing.remove();
          }
          embed.insertAdjacentHTML('beforeend', data.html);
        }
        embed.classList.add('is-archived');
      })
      .catch(() => {
        /* network hiccup — leave the live widget in place */
      });
  });
}
