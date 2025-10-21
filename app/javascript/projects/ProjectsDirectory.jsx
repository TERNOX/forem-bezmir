import { h } from 'preact';
import { useEffect, useMemo, useRef, useState } from 'preact/hooks';
import { locale } from '@utilities/locale';

const SORT_OPTIONS = [
  { value: 'reputation_desc', labelKey: 'views.projects.index.sort_options.reputation_desc' },
  { value: 'reputation_asc', labelKey: 'views.projects.index.sort_options.reputation_asc' },
  { value: 'newest', labelKey: 'views.projects.index.sort_options.newest' },
  { value: 'oldest', labelKey: 'views.projects.index.sort_options.oldest' },
];

const formatDate = (value) => {
  if (!value) {
    return '';
  }

  try {
    const formatter = new Intl.DateTimeFormat(document.body.dataset.locale || 'en', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
    return formatter.format(new Date(value));
  } catch (error) {
    return new Date(value).toLocaleDateString();
  }
};

const updateUrl = (query, sort) => {
  const url = new URL(window.location.href);
  if (query) {
    url.searchParams.set('q', query);
  } else {
    url.searchParams.delete('q');
  }

  if (sort && sort !== 'reputation_desc') {
    url.searchParams.set('sort', sort);
  } else {
    url.searchParams.delete('sort');
  }

  window.history.replaceState({}, '', `${url.pathname}${url.search}`);
};

export const ProjectsDirectory = ({
  initialProjects = [],
  initialMeta = {},
  perPage,
  initialQuery = '',
  initialSort = 'reputation_desc',
}) => {
  const pageSize = Number(perPage) || 24;
  const [projects, setProjects] = useState(initialProjects);
  const [meta, setMeta] = useState({
    page: initialMeta.page || 1,
    totalPages: initialMeta.total_pages || 1,
    totalCount: initialMeta.total_count || initialProjects.length,
  });
  const [query, setQuery] = useState(initialQuery);
  const [sort, setSort] = useState(initialSort);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState(null);
  const abortRef = useRef();
  const firstRun = useRef(true);
  const debounceRef = useRef();

  const hasMore = useMemo(() => meta.page < meta.totalPages, [meta.page, meta.totalPages]);

  const fetchProjects = (requestedPage, replace = false) => {
    if (replace && abortRef.current) {
      abortRef.current.abort();
    }

    const controller = new AbortController();
    if (replace) {
      abortRef.current = controller;
      setLoading(true);
    } else {
      setLoadingMore(true);
    }
    setError(null);

    const params = new URLSearchParams();
    params.set('page', requestedPage);
    params.set('per_page', pageSize);
    if (query) {
      params.set('q', query);
    }
    if (sort) {
      params.set('sort', sort);
    }

    fetch(`/projects.json?${params.toString()}`, { signal: controller.signal })
      .then((response) => {
        if (!response.ok) {
          throw new Error('Request failed');
        }
        return response.json();
      })
      .then((data) => {
        setProjects((prev) => (replace ? data.projects : [...prev, ...data.projects]));
        setMeta({
          page: data.meta.page,
          totalPages: data.meta.total_pages,
          totalCount: data.meta.total_count,
        });
      })
      .catch((err) => {
        if (err.name === 'AbortError') {
          return;
        }
        setError(locale('views.projects.index.error'));
      })
      .finally(() => {
        setLoading(false);
        setLoadingMore(false);
        if (replace && abortRef.current === controller) {
          abortRef.current = null;
        }
      });
  };

  useEffect(() => {
    if (firstRun.current) {
      firstRun.current = false;
      return;
    }

    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    debounceRef.current = setTimeout(() => {
      updateUrl(query, sort);
      fetchProjects(1, true);
    }, 250);

    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, [query, sort]);

  const handleSubmit = (event) => {
    event.preventDefault();
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }
    updateUrl(query, sort);
    fetchProjects(1, true);
  };

  const handleSortChange = (event) => {
    setSort(event.target.value);
  };

  const handleQueryChange = (event) => {
    setQuery(event.target.value);
  };

  const loadMore = () => {
    if (loading || loadingMore || !hasMore) {
      return;
    }
    fetchProjects(meta.page + 1, false);
  };

  return (
    <section aria-live="polite">
      <form className="projects-directory__controls" onSubmit={handleSubmit}>
        <div className="projects-directory__controls-form">
          <label className="crayons-field projects-directory__search-field">
            <span className="crayons-field__label">
              {locale('views.projects.index.search_label')}
            </span>
            <input
              className="crayons-textfield"
              type="search"
              value={query}
              onInput={handleQueryChange}
              placeholder={locale('views.projects.index.search_placeholder')}
              aria-label={locale('views.projects.index.search_label')}
            />
          </label>
          <label className="crayons-field projects-directory__sort-field">
            <span className="crayons-field__label">
              {locale('views.projects.index.sort_label')}
            </span>
            <select
              className="crayons-select"
              value={sort}
              onChange={handleSortChange}
              aria-label={locale('views.projects.index.sort_label')}
            >
              {SORT_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {locale(option.labelKey)}
                </option>
              ))}
            </select>
          </label>
          <button
            type="submit"
            className="crayons-btn crayons-btn--secondary"
            disabled={loading}
          >
            {locale('views.projects.index.apply_filters')}
          </button>
        </div>
      </form>

      {error && <div className="projects-directory__error" role="alert">{error}</div>}

      {!projects.length && !loading && !loadingMore ? (
        <div className="projects-directory__empty">
          {locale('views.projects.index.empty_state')}
        </div>
      ) : (
        <div className="projects-directory__grid" role="list">
          {projects.map((project) => (
            <article
              className="crayons-card projects-directory__card"
              key={project.id}
              role="listitem"
            >
              <a className="projects-directory__card-header" href={`/${project.slug}`}>
                {project.profile_image ? (
                  <img
                    alt={locale('views.projects.index.logo_alt', { name: project.name })}
                    className="projects-directory__image"
                    src={project.profile_image}
                    loading="lazy"
                    width="72"
                    height="72"
                  />
                ) : (
                  <div className="projects-directory__image crayons-avatar--no-image" aria-hidden="true" />
                )}
                <div>
                  <h2 className="projects-directory__title fs-xl fw-bold">{project.name}</h2>
                  {project.tag_line && (
                    <p className="projects-directory__tagline fs-s color-base-70">{project.tag_line}</p>
                  )}
                </div>
              </a>
              {project.summary && (
                <p className="projects-directory__summary fs-base">{project.summary}</p>
              )}
              <dl className="projects-directory__meta">
                <div className="projects-directory__meta-item">
                  <dt className="projects-directory__meta-label">
                    {locale('views.projects.index.reputation_label')}
                  </dt>
                  <dd className="projects-directory__meta-value">
                    {project.reputation_score}
                  </dd>
                </div>
                <div className="projects-directory__meta-item">
                  <dt className="projects-directory__meta-label">
                    {locale('views.projects.index.created_label')}
                  </dt>
                  <dd className="projects-directory__meta-value">
                    {formatDate(project.created_at)}
                  </dd>
                </div>
                <div className="projects-directory__meta-item">
                  <dt className="projects-directory__meta-label">
                    {locale('views.projects.index.posts_label')}
                  </dt>
                  <dd className="projects-directory__meta-value">
                    {project.articles_count}
                  </dd>
                </div>
              </dl>
              {project.url && (
                <a
                  className="crayons-link--branded projects-directory__external-link"
                  href={project.url}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  {locale('views.projects.index.visit_link')}
                </a>
              )}
            </article>
          ))}
        </div>
      )}

      {(loading || loadingMore) && (
        <div className="projects-directory__loading" role="status">
          {locale('core.loading')}
        </div>
      )}

      {hasMore && (
        <div className="projects-directory__actions">
          <button
            type="button"
            className="crayons-btn"
            onClick={loadMore}
            disabled={loading || loadingMore}
          >
            {loadingMore
              ? locale('core.loading')
              : locale('views.projects.index.load_more')}
          </button>
        </div>
      )}
    </section>
  );
};
