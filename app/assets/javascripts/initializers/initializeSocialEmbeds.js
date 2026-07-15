/* Fork-only: for each embedded social post (Twitter/X, Bluesky) that has a durable
   archive card, ask our own liveness endpoint whether the original is gone; if so,
   swap the dead platform widget for the self-hosted archive card. Live posts are
   left untouched. Safe to run repeatedly (InstantClick re-runs initializers). */
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

    // Nothing to fall back to if we never captured a snapshot.
    if (!embed.querySelector('.ltag-social-embed__archive')) {
      return;
    }

    // Already archived server-side (source was gone when the article rendered).
    if (
      embed.classList.contains('is-archived') ||
      embed.dataset.status === 'deleted'
    ) {
      embed.classList.add('is-archived');
      return;
    }

    const platform = embed.dataset.platform;
    const sourceId = embed.dataset.sourceId;
    if (!platform || !sourceId) {
      return;
    }

    const url =
      '/social_embeds/status?platform=' +
      encodeURIComponent(platform) +
      '&source_id=' +
      encodeURIComponent(sourceId);

    window
      .fetch(url, {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      })
      .then((response) => (response.ok ? response.json() : null))
      .then((data) => {
        if (data && (data.status === 'deleted' || data.archived)) {
          embed.classList.add('is-archived');
        }
      })
      .catch(() => {
        /* network hiccup — leave the live widget in place */
      });
  });
}
