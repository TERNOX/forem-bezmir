import { h, Fragment } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';
import PropTypes from 'prop-types';
import { NomineeCard } from './NomineeCard';
import {
  emptySelection,
  fromBallot,
  interpolate,
  isAnswered,
  isSingleChoice,
  pickCount,
  pruneSelections,
  sameSelections,
  setOther,
  toggleNominee,
  toPayload,
} from './selection';
import { request } from '@utilities/http';

const draftKey = (slug) => `voting-draft:${slug}`;

function readDraft(slug) {
  try {
    const raw = window.localStorage.getItem(draftKey(slug));
    return raw ? JSON.parse(raw) : null;
  } catch (_) {
    return null;
  }
}

function writeDraft(slug, selections) {
  try {
    window.localStorage.setItem(draftKey(slug), JSON.stringify(selections));
  } catch (_) {
    // Private mode / storage full: the draft is a convenience only.
  }
}

function clearDraft(slug) {
  try {
    window.localStorage.removeItem(draftKey(slug));
  } catch (_) {
    // ignore
  }
}

/**
 * Fork-only: the community voting app ("Гра року"). One nomination per step,
 * a clickable list of all nominations underneath, a summary step, then submit.
 * Guests can click through; their picks are kept locally until they sign in.
 */
export function VotingApp({ voting, categories, results, strings, signInUrl }) {
  const msg = (key, vars) => interpolate(strings[key] ?? key, vars);
  const summaryStep = categories.length;
  const rootRef = useRef(null);

  const readOnly = !(voting.status === 'open' || voting.status === 'draft');

  const [loading, setLoading] = useState(true);
  // The layout already knows whether someone is signed in, so the guest hint
  // renders straight away instead of popping in (and shifting the page) later.
  const [account, setAccount] = useState({
    signedIn: document.body?.dataset.userStatus === 'logged-in',
    eligible: false,
    reason: null,
  });
  // A local draft is available synchronously; picks made before the ballot
  // request finishes must not be overwritten by its response.
  const [selections, setSelections] = useState(() =>
    pruneSelections(!readOnly && readDraft(voting.slug), categories),
  );
  const touchedRef = useRef(false);
  const [savedSelections, setSavedSelections] = useState({});
  const [submittedAt, setSubmittedAt] = useState(null);
  const [shareUrl, setShareUrl] = useState(null);
  const [step, setStep] = useState(0);
  const [view, setView] = useState(
    voting.status === 'closed' && results ? 'results' : 'vote',
  );
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState({});
  const [flash, setFlash] = useState(null);
  const [updatedVote, setUpdatedVote] = useState(false);

  useEffect(() => {
    let cancelled = false;
    request(voting.ballotUrl, { method: 'GET' })
      .then((response) => response.json())
      .then((data) => {
        if (cancelled) return;
        const server = pruneSelections(fromBallot(data.ballot), categories);
        const draft = readDraft(voting.slug);
        setAccount({
          signedIn: data.signedIn,
          eligible: data.eligible,
          reason: data.reason,
        });
        setSavedSelections(server);
        setSubmittedAt(data.ballot?.submittedAt || null);
        setShareUrl(data.shareUrl || null);
        if (!touchedRef.current) {
          setSelections(
            draft && !readOnly ? pruneSelections(draft, categories) : server,
          );
        }
      })
      .catch(() => {})
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [voting.ballotUrl, voting.slug, readOnly, categories]);

  const answeredCount = categories.filter((c) =>
    isAnswered(selections[c.id]),
  ).length;
  const dirty = !sameSelections(selections, savedSelections);
  const missingRequired = categories.filter(
    (c) => c.required && !isAnswered(selections[c.id]),
  );

  const scrollToApp = () => {
    rootRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const goTo = (index) => {
    setStep(Math.max(0, Math.min(summaryStep, index)));
    setFlash(null);
    scrollToApp();
  };

  const updateSelection = (category, nextSelection) => {
    touchedRef.current = true;
    const next = { ...selections, [category.id]: nextSelection };
    setSelections(next);
    setErrors((prev) => {
      const copy = { ...prev };
      delete copy[category.id];
      delete copy.base;
      return copy;
    });
    if (!readOnly) writeDraft(voting.slug, next);
  };

  const onToggle = (category, nomineeId) => {
    const { selection, limitReached } = toggleNominee(
      category,
      selections[category.id],
      nomineeId,
    );
    if (limitReached) {
      setFlash(msg('limit_reached', { count: category.maxChoices }));
      return;
    }
    setFlash(null);
    updateSelection(category, selection);
  };

  const submit = async () => {
    if (!account.signedIn) {
      writeDraft(voting.slug, selections);
      if (typeof window.showLoginModal === 'function') {
        window.showLoginModal({ referring_source: 'voting', trigger: 'vote' });
      } else {
        window.location.href = signInUrl;
      }
      return;
    }
    setSaving(true);
    setErrors({});
    const wasSubmitted = Boolean(submittedAt);
    try {
      const response = await request(voting.ballotUrl, {
        method: 'PUT',
        body: { selections: toPayload(selections) },
      });
      const data = await response.json();
      if (!response.ok) {
        setErrors(data.errors || { base: ['generic'] });
        const firstBad = categories.findIndex((c) => data.errors?.[c.id]);
        if (firstBad >= 0) goTo(firstBad);
        return;
      }
      const saved = fromBallot(data.ballot);
      setSavedSelections(saved);
      setSelections(saved);
      setSubmittedAt(data.ballot.submittedAt);
      setShareUrl(data.shareUrl);
      clearDraft(voting.slug);
      setUpdatedVote(wasSubmitted);
      setView('thanks');
      scrollToApp();
    } catch (_) {
      setErrors({ base: ['generic'] });
    } finally {
      setSaving(false);
    }
  };

  if (view === 'results' && results) {
    return (
      <div ref={rootRef}>
        <ResultsView
          categories={categories}
          results={results}
          savedSelections={savedSelections}
          msg={msg}
          strings={strings}
          onBack={() => setView('vote')}
        />
      </div>
    );
  }

  if (view === 'thanks') {
    return (
      <div ref={rootRef}>
        <ThanksView
          voting={voting}
          shareUrl={shareUrl}
          updated={updatedVote}
          msg={msg}
          onEdit={() => {
            setView('vote');
            goTo(summaryStep);
          }}
        />
      </div>
    );
  }

  const category = categories[step];

  return (
    <div className="voting-app" ref={rootRef}>
      <StatusBar
        voting={voting}
        account={account}
        loading={loading}
        msg={msg}
        hasResults={Boolean(results)}
        onShowResults={() => setView('results')}
      />

      <div
        className="voting-progress"
        role="group"
        aria-label={msg('progress', {
          done: answeredCount,
          total: categories.length,
        })}
      >
        <div className="voting-progress__bar">
          <span
            style={{
              width: `${(answeredCount / Math.max(categories.length, 1)) * 100}%`,
            }}
          />
        </div>
        <span className="voting-progress__label">
          {msg('progress', { done: answeredCount, total: categories.length })}
        </span>
      </div>

      {step < summaryStep && category ? (
        <CategoryStep
          key={category.id}
          category={category}
          index={step}
          total={categories.length}
          selection={selections[category.id] || emptySelection()}
          errors={errors[category.id]}
          readOnly={readOnly}
          flash={flash}
          strings={strings}
          msg={msg}
          onToggle={(id) => onToggle(category, id)}
          onOther={(text) =>
            updateSelection(
              category,
              setOther(category, selections[category.id], text),
            )
          }
          onBack={() => goTo(step - 1)}
          onNext={() => goTo(step + 1)}
        />
      ) : (
        <SummaryStep
          categories={categories}
          selections={selections}
          errors={errors}
          missingRequired={missingRequired}
          account={account}
          loading={loading}
          readOnly={readOnly}
          saving={saving}
          dirty={dirty}
          submitted={Boolean(submittedAt)}
          shareUrl={shareUrl}
          msg={msg}
          onJump={goTo}
          onSubmit={submit}
          onBack={() => goTo(summaryStep - 1)}
        />
      )}

      <nav className="voting-steps" aria-label={msg('all_nominations')}>
        <h2 className="voting-steps__title">{msg('all_nominations')}</h2>
        <ol className="voting-steps__list">
          {categories.map((c, index) => {
            const answered = isAnswered(selections[c.id]);
            return (
              <li key={c.id}>
                <button
                  type="button"
                  className={`voting-steps__item${index === step ? ' voting-steps__item--current' : ''}${
                    answered ? ' voting-steps__item--answered' : ''
                  }${errors[c.id] ? ' voting-steps__item--error' : ''}`}
                  aria-current={index === step ? 'step' : undefined}
                  onClick={() => goTo(index)}
                >
                  <span className="voting-steps__number" aria-hidden="true">
                    {answered ? '✓' : index + 1}
                  </span>
                  <span className="voting-steps__name">
                    {c.title}
                    {c.required && (
                      <span
                        className="voting-steps__required"
                        title={msg('required')}
                      >
                        {' '}
                        *
                      </span>
                    )}
                  </span>
                </button>
              </li>
            );
          })}
          <li>
            <button
              type="button"
              className={`voting-steps__item voting-steps__item--summary${step === summaryStep ? ' voting-steps__item--current' : ''}`}
              aria-current={step === summaryStep ? 'step' : undefined}
              onClick={() => goTo(summaryStep)}
            >
              <span className="voting-steps__number" aria-hidden="true">
                ★
              </span>
              <span className="voting-steps__name">{msg('summary_title')}</span>
            </button>
          </li>
        </ol>
      </nav>
    </div>
  );
}

function StatusBar({
  voting,
  account,
  loading,
  msg,
  hasResults,
  onShowResults,
}) {
  let text = '';
  if (voting.status === 'upcoming')
    text = msg('status_upcoming', { date: voting.opensAtText });
  else if (voting.status === 'closed') text = msg('status_closed');
  else if (voting.status === 'draft') text = msg('status_draft');
  else if (voting.closesAtText)
    text = msg('status_open_until', { date: voting.closesAtText });

  const reason =
    !loading && account.signedIn && !account.eligible && account.reason;
  const guestHint = !account.signedIn && voting.status === 'open';
  // Results are shown once an admin publishes them, even while voting is
  // still open (or has no closing date).
  const showResultsButton = hasResults;
  if (
    !text &&
    !reason &&
    !guestHint &&
    !hasResults &&
    voting.status !== 'closed'
  ) {
    return null;
  }
  return (
    <div className="voting-status">
      {text && <p className="voting-status__text">{text}</p>}
      {voting.status === 'closed' && !hasResults && (
        <p className="voting-status__text">{msg('results_soon')}</p>
      )}
      {showResultsButton && (
        <button
          type="button"
          className="crayons-btn crayons-btn--secondary"
          onClick={onShowResults}
        >
          {msg('show_results')}
        </button>
      )}
      {reason && reason !== 'closed' && reason !== 'upcoming' && (
        <p className="crayons-notice crayons-notice--warning" role="status">
          {msg(`reason_${reason}`)}
        </p>
      )}
      {guestHint && <p className="voting-status__hint">{msg('guest_hint')}</p>}
    </div>
  );
}

function hintFor(category, msg) {
  if (category.ranked) {
    return msg('hint_ranked', {
      count: category.maxChoices,
      points: category.points.join(' · '),
    });
  }
  if (isSingleChoice(category)) return msg('hint_single');
  return msg('hint_multi', { count: category.maxChoices });
}

function CategoryStep({
  category,
  index,
  total,
  selection,
  errors,
  readOnly,
  flash,
  strings,
  msg,
  onToggle,
  onOther,
  onBack,
  onNext,
}) {
  const count = pickCount(selection);
  const full = !isSingleChoice(category) && count >= category.maxChoices;
  const answered = count > 0;

  return (
    <section
      className="voting-step"
      aria-labelledby={`voting-step-${category.id}`}
    >
      <header className="voting-step__header">
        <p className="voting-step__counter">
          {msg('step', { current: index + 1, total })}
          <span
            className={`voting-step__tag${category.required ? ' voting-step__tag--required' : ''}`}
          >
            {category.required ? msg('required') : msg('optional')}
          </span>
        </p>
        <h2 className="voting-step__title" id={`voting-step-${category.id}`}>
          {category.title}
        </h2>
        {category.description && (
          <p className="voting-step__description">{category.description}</p>
        )}
        {!readOnly && (
          <p className="voting-step__hint">
            {hintFor(category, msg)}
            {!isSingleChoice(category) && (
              <span className="voting-step__count" aria-live="polite">
                {' '}
                {msg('selected_count', { count, max: category.maxChoices })}
              </span>
            )}
          </p>
        )}
      </header>

      {errors && (
        <p className="crayons-notice crayons-notice--danger mb-4" role="alert">
          {errors.map((code) => msg(`error_${code}`)).join(' ')}
        </p>
      )}
      {flash && (
        <p className="voting-step__flash" role="status">
          {flash}
        </p>
      )}

      <ul className={`voting-grid voting-grid--${category.cardStyle}`}>
        {category.nominees.map((nominee) => {
          const position = selection.ids.indexOf(nominee.id);
          const selected = position >= 0;
          return (
            <NomineeCard
              key={nominee.id}
              nominee={nominee}
              cardStyle={category.cardStyle}
              selected={selected}
              place={category.ranked && selected ? position + 1 : undefined}
              disabled={!selected && full}
              readOnly={readOnly}
              strings={strings}
              onToggle={onToggle}
            />
          );
        })}
      </ul>

      {category.allowOther && !readOnly && (
        <div className="voting-other crayons-field">
          <label
            className="crayons-field__label"
            htmlFor={`voting-other-${category.id}`}
          >
            {msg('other_label')}
          </label>
          <input
            id={`voting-other-${category.id}`}
            type="text"
            className="crayons-textfield"
            maxLength={100}
            placeholder={msg('other_placeholder')}
            value={selection.other}
            disabled={full && !selection.other.trim()}
            onInput={(event) => onOther(event.currentTarget.value)}
          />
        </div>
      )}

      <footer className="voting-step__nav">
        {index > 0 ? (
          <button
            type="button"
            className="crayons-btn crayons-btn--secondary"
            onClick={onBack}
          >
            ← {msg('back')}
          </button>
        ) : (
          <span />
        )}
        <button
          type="button"
          className={`crayons-btn${answered || readOnly || index === total - 1 ? '' : ' crayons-btn--secondary'}`}
          onClick={onNext}
        >
          {index === total - 1
            ? msg('to_summary')
            : answered || readOnly
              ? msg('next')
              : msg('skip')}{' '}
          →
        </button>
      </footer>
    </section>
  );
}

function SummaryStep({
  categories,
  selections,
  errors,
  missingRequired,
  account,
  loading,
  readOnly,
  saving,
  dirty,
  submitted,
  shareUrl,
  msg,
  onJump,
  onSubmit,
  onBack,
}) {
  // While the ballot request is in flight we don't know eligibility yet: keep
  // the button in place (disabled) instead of letting it pop in later.
  const canSubmit =
    !readOnly && (!account.signedIn || account.eligible || loading);
  const answered = categories.filter((c) =>
    isAnswered(selections[c.id]),
  ).length;
  let buttonLabel = submitted ? msg('update') : msg('submit');
  if (!account.signedIn) buttonLabel = msg('sign_in_to_vote');
  if (saving) buttonLabel = msg('saving');

  return (
    <section
      className="voting-step voting-summary"
      aria-labelledby="voting-summary-title"
    >
      <header className="voting-step__header">
        <h2 className="voting-step__title" id="voting-summary-title">
          {msg('summary_title')}
        </h2>
        {!readOnly && (
          <p className="voting-step__description">{msg('summary_hint')}</p>
        )}
      </header>

      <ol className="voting-summary__list">
        {categories.map((category, index) => {
          const selection = selections[category.id] || emptySelection();
          const nominees = selection.ids
            .map((id) => category.nominees.find((n) => n.id === id))
            .filter(Boolean);
          return (
            <li
              key={category.id}
              className={`voting-summary__item${errors[category.id] ? ' voting-summary__item--error' : ''}`}
            >
              <button
                type="button"
                className="voting-summary__button"
                onClick={() => onJump(index)}
              >
                <span className="voting-summary__name">
                  {category.title}
                  {category.required && ' *'}
                </span>
                <span className="voting-summary__picks">
                  {nominees.length === 0 && !selection.other.trim() && (
                    <span className="voting-summary__empty">
                      {msg('nothing_selected')}
                    </span>
                  )}
                  {nominees.map((nominee, place) => (
                    <span key={nominee.id} className="voting-summary__pick">
                      {nominee.imageUrl && (
                        <img src={nominee.imageUrl} alt="" loading="lazy" />
                      )}
                      <span>
                        {category.ranked ? `${place + 1}. ` : ''}
                        {nominee.title}
                      </span>
                    </span>
                  ))}
                  {selection.other.trim() && (
                    <span className="voting-summary__pick">
                      <span>
                        {msg('other_label')}: {selection.other.trim()}
                      </span>
                    </span>
                  )}
                </span>
              </button>
            </li>
          );
        })}
      </ol>

      {errors.base && (
        <p className="crayons-notice crayons-notice--danger" role="alert">
          {errors.base.map((code) => msg(`error_${code}`, {})).join(' ')}
        </p>
      )}
      {missingRequired.length > 0 && !readOnly && (
        <p className="crayons-notice crayons-notice--warning" role="status">
          {msg('missing_required', {
            list: missingRequired.map((c) => c.title).join(', '),
          })}
        </p>
      )}

      <footer className="voting-step__nav">
        <button
          type="button"
          className="crayons-btn crayons-btn--secondary"
          onClick={onBack}
        >
          ← {msg('back')}
        </button>
        {canSubmit && (
          <button
            type="button"
            className="crayons-btn crayons-btn--l"
            onClick={onSubmit}
            disabled={
              saving ||
              loading ||
              answered === 0 ||
              missingRequired.length > 0 ||
              (submitted && !dirty)
            }
          >
            {buttonLabel}
          </button>
        )}
      </footer>
      {!account.signedIn && canSubmit && (
        <p className="voting-status__hint mt-2">{msg('sign_in_hint')}</p>
      )}
      {submitted && !dirty && !readOnly && (
        <p className="voting-status__hint mt-2">
          {msg('already_voted')}{' '}
          {shareUrl && <a href={shareUrl}>{msg('see_my_picks')}</a>}
        </p>
      )}
    </section>
  );
}

function ThanksView({ voting, shareUrl, updated, msg, onEdit }) {
  const [copied, setCopied] = useState(false);
  const [imageReady, setImageReady] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const imageUrl = shareUrl ? `${shareUrl}/image?attempt=${attempt}` : null;

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(shareUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    } catch (_) {
      window.prompt(msg('share_copy'), shareUrl); // eslint-disable-line no-alert
    }
  };

  const nativeShare = () => {
    navigator.share?.({ title: voting.title, url: shareUrl }).catch(() => {});
  };

  const encoded = encodeURIComponent(shareUrl || '');
  const text = encodeURIComponent(msg('share_text', { title: voting.title }));

  return (
    <section className="voting-thanks crayons-card">
      <h2 className="voting-thanks__title">
        {updated ? msg('thanks_updated') : msg('thanks_title')}
      </h2>
      {voting.closesAtText && (
        <p className="voting-thanks__text">
          {msg('thanks_body', { date: voting.closesAtText })}
        </p>
      )}

      {shareUrl && (
        <div className="voting-share">
          <h3 className="voting-share__title">{msg('share_title')}</h3>
          <div className="voting-share__preview">
            {!imageReady && (
              <span className="voting-share__loading">
                {msg('image_generating')}
              </span>
            )}
            {imageUrl && (
              <img
                src={imageUrl}
                alt={msg('share_image_alt', { title: voting.title })}
                width="1200"
                height="630"
                onLoad={() => setImageReady(true)}
                onError={() =>
                  attempt < 8 && setTimeout(() => setAttempt(attempt + 1), 3000)
                }
                style={{ visibility: imageReady ? 'visible' : 'hidden' }}
              />
            )}
          </div>
          <div className="voting-share__actions">
            <a
              className="crayons-btn"
              href={`${shareUrl}/image`}
              download={`${voting.slug}.png`}
            >
              {msg('share_download')}
            </a>
            <button
              type="button"
              className="crayons-btn crayons-btn--secondary"
              onClick={copy}
            >
              {copied ? msg('share_copied') : msg('share_copy')}
            </button>
            {typeof navigator !== 'undefined' && navigator.share && (
              <button
                type="button"
                className="crayons-btn crayons-btn--secondary"
                onClick={nativeShare}
              >
                {msg('share_native')}
              </button>
            )}
          </div>
          <div className="voting-share__networks">
            <span className="voting-share__networks-label">
              {msg('share_on')}
            </span>
            {[
              [
                'Telegram',
                `https://t.me/share/url?url=${encoded}&text=${text}`,
              ],
              ['X', `https://x.com/intent/post?url=${encoded}&text=${text}`],
              [
                'Bluesky',
                `https://bsky.app/intent/compose?text=${text}%20${encoded}`,
              ],
              [
                'Facebook',
                `https://www.facebook.com/sharer/sharer.php?u=${encoded}`,
              ],
            ].map(([name, href]) => (
              <a
                key={name}
                className="crayons-btn crayons-btn--outlined crayons-btn--s"
                href={href}
                target="_blank"
                rel="noopener noreferrer"
              >
                {name}
              </a>
            ))}
          </div>
          <a className="voting-share__page" href={shareUrl}>
            {msg('see_my_picks')}
          </a>
        </div>
      )}

      <button
        type="button"
        className="crayons-btn crayons-btn--ghost mt-4"
        onClick={onEdit}
      >
        {msg('edit_answers')}
      </button>
    </section>
  );
}

function ResultsView({
  categories,
  results,
  savedSelections,
  msg,
  strings,
  onBack,
}) {
  return (
    <div className="voting-results">
      <h2 className="voting-results__title">{msg('results_title')}</h2>
      <p className="voting-status__text">
        {msg('ballots_count', { count: results.ballotsCount })}
      </p>
      {categories.map((category) => {
        const categoryResult = results.categories[category.id] || {
          rows: [],
          voters: 0,
        };
        const mine = savedSelections[category.id]?.ids || [];
        const byId = Object.fromEntries(
          category.nominees.map((n) => [n.id, n]),
        );
        const topPoints = categoryResult.rows[0]?.points || 0;
        return (
          <section key={category.id} className="voting-results__category">
            <h3 className="voting-step__title">{category.title}</h3>
            <p className="voting-step__counter">
              {msg('voters_count', { count: categoryResult.voters })}
            </p>
            <ol className="voting-results__rows">
              {categoryResult.rows.map((row, index) => {
                const nominee = byId[row.nomineeId];
                if (!nominee) return null;
                const winner = topPoints > 0 && row.points === topPoints;
                return (
                  <li
                    key={row.nomineeId}
                    className={`voting-results__row${winner ? ' voting-results__row--winner' : ''}`}
                  >
                    <span className="voting-results__place">
                      {winner ? '🏆' : index + 1}
                    </span>
                    {nominee.imageUrl && (
                      <img
                        className="voting-results__image"
                        src={nominee.imageUrl}
                        alt=""
                        loading="lazy"
                      />
                    )}
                    <span className="voting-results__body">
                      <span className="voting-results__name">
                        {nominee.title}
                        {mine.includes(nominee.id) && (
                          <span className="voting-results__mine">
                            {msg('your_pick')}
                          </span>
                        )}
                      </span>
                      <span className="voting-results__bar">
                        <span style={{ width: `${row.share}%` }} />
                      </span>
                    </span>
                    <span className="voting-results__points">
                      {category.ranked
                        ? msg('points', { count: row.points })
                        : msg('votes', { count: row.votes })}
                    </span>
                  </li>
                );
              })}
            </ol>
          </section>
        );
      })}
      {strings.results_footer && (
        <p className="voting-status__hint">{msg('results_footer')}</p>
      )}
      <div className="voting-results__actions">
        <button
          type="button"
          className="crayons-btn crayons-btn--secondary"
          onClick={onBack}
        >
          {msg('back_to_voting')}
        </button>
      </div>
    </div>
  );
}

VotingApp.propTypes = {
  voting: PropTypes.object.isRequired,
  categories: PropTypes.array.isRequired,
  results: PropTypes.object,
  strings: PropTypes.object.isRequired,
  signInUrl: PropTypes.string.isRequired,
};
