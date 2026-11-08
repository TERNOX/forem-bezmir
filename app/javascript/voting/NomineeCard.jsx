import { h } from 'preact';
import PropTypes from 'prop-types';

/**
 * Fork-only: one nominee tile. A real <button> with aria-pressed so it works
 * with the keyboard and screen readers; ranked picks show their place badge.
 */
export function NomineeCard({
  nominee,
  cardStyle,
  selected,
  place,
  disabled,
  readOnly,
  onToggle,
  strings,
  resultShare,
  isWinner,
}) {
  const label = place
    ? `${nominee.title}, ${strings.place_label.replace('%{place}', place)}`
    : nominee.title;

  const body = (
    <span>
      <span className={`voting-card__image voting-card__image--${cardStyle}`}>
        {nominee.imageUrl ? (
          <img src={nominee.imageUrl} alt="" loading="lazy" decoding="async" />
        ) : (
          <span className="voting-card__placeholder" aria-hidden="true">
            {nominee.title.slice(0, 1)}
          </span>
        )}
        {place && (
          <span className="voting-place-badge" aria-hidden="true">
            {place}
          </span>
        )}
        {selected && !place && (
          <span className="voting-card__check" aria-hidden="true">
            ✓
          </span>
        )}
        {isWinner && (
          <span className="voting-card__trophy" aria-hidden="true">
            🏆
          </span>
        )}
      </span>
      <span className="voting-card__text">
        <span className="voting-card__title">{nominee.title}</span>
        {nominee.subtitle && (
          <span className="voting-card__subtitle">{nominee.subtitle}</span>
        )}
      </span>
      {resultShare !== undefined && (
        <span className="voting-card__bar" aria-hidden="true">
          <span style={{ width: `${resultShare}%` }} />
        </span>
      )}
    </span>
  );

  return (
    <li
      className={`voting-card voting-card--${cardStyle}${selected ? ' voting-card--selected' : ''}${
        isWinner ? ' voting-card--winner' : ''
      }`}
    >
      {readOnly ? (
        <div className="voting-card__button" aria-label={label}>
          {body}
        </div>
      ) : (
        <button
          type="button"
          className="voting-card__button"
          aria-pressed={selected ? 'true' : 'false'}
          aria-label={label}
          disabled={disabled}
          onClick={() => onToggle(nominee.id)}
        >
          {body}
        </button>
      )}
      {nominee.linkUrl && (
        <a
          className="voting-card__link"
          href={nominee.linkUrl}
          target="_blank"
          rel="noopener noreferrer"
        >
          {strings.open_link}
        </a>
      )}
    </li>
  );
}

NomineeCard.propTypes = {
  nominee: PropTypes.shape({
    id: PropTypes.number.isRequired,
    title: PropTypes.string.isRequired,
    subtitle: PropTypes.string,
    imageUrl: PropTypes.string,
    linkUrl: PropTypes.string,
  }).isRequired,
  cardStyle: PropTypes.string.isRequired,
  selected: PropTypes.bool,
  place: PropTypes.number,
  disabled: PropTypes.bool,
  readOnly: PropTypes.bool,
  onToggle: PropTypes.func,
  strings: PropTypes.object.isRequired,
  resultShare: PropTypes.number,
  isWinner: PropTypes.bool,
};
