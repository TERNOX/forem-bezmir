'use strict';

function secondsToHumanUnitAgo(seconds) {
  const i18n =
    typeof globalThis !== 'undefined' &&
    globalThis.I18n &&
    typeof globalThis.I18n.t === 'function'
      ? globalThis.I18n
      : null;

  const fallbackFormatter = (unit) => (count) =>
    `${count} ${unit}${count === 1 ? '' : ''} тому`;

  const times = [
    {
      seconds: 1,
      translationKey: 'datetime.distance_in_words_ago.x_seconds',
      fallback: fallbackFormatter('сек'),
    },
    {
      seconds: 60,
      translationKey: 'datetime.distance_in_words_ago.x_minutes',
      fallback: fallbackFormatter('хв'),
    },
    {
      seconds: 60 * 60,
      translationKey: 'datetime.distance_in_words_ago.about_x_hours',
      fallback: fallbackFormatter('год'),
    },
    {
      seconds: 60 * 60 * 24,
      translationKey: 'datetime.distance_in_words_ago.x_days',
      fallback: fallbackFormatter('день'),
    },
    {
      seconds: 60 * 60 * 24 * 30,
      translationKey: 'datetime.distance_in_words_ago.x_months',
      fallback: fallbackFormatter('місяць'),
    },
    {
      seconds: 60 * 60 * 24 * 365,
      translationKey: 'datetime.distance_in_words_ago.x_years',
      fallback: fallbackFormatter('рік'),
    },
  ];

  if (seconds < times[0].seconds) {
    if (i18n) {
      return i18n.t('datetime.distance_in_words_ago.less_than_x_seconds', {
        count: 1,
      });
    }

    return 'прямо зараз';
  }

  let scale = 0;
  // If the amount of seconds is more than a minute, we change the scale to minutes
  // If the amount of seconds then is more than an hour, we change the scale to hours
  // This continues until the unit above our current scale is longer than `seconds`, or doesn't exist
  while (scale + 1 < times.length && seconds >= times[scale + 1].seconds) scale += 1;

  const timeScale = times[scale];
  const wholeUnits = Math.floor(seconds / timeScale.seconds);

  if (i18n) {
    return i18n.t(timeScale.translationKey, { count: wholeUnits });
  }

  return timeScale.fallback(wholeUnits);
}

/**
 * Returns a given time in seconds as a human readable form, e.g. (5 min ago)
 *
 * @param {object} options
 * @param {number} options.oldTimeInSeconds
 * @param {function} [(humanTime) =>
      `<span class="time-ago-indicator">(${humanTime})</span>`] options.formatter
 * @param {number} [60 * 60 * 24 - 1] options.maxDisplayedAge The maximum display age in seconds
 *
 * @returns {string} A formatted string in human readable form. Note that the default formatter returns a string with markup in it.
 */
function timeAgo({
  oldTimeInSeconds,
  formatter = (humanTime) =>
    `<span class="time-ago-indicator">(${humanTime})</span>`,
  maxDisplayedAge = 60 * 60 * 24 - 1,
}) {
  const timeNow = new Date() / 1000;
  const diff = Math.round(timeNow - oldTimeInSeconds);

  if (diff > maxDisplayedAge) return '';

  return formatter(secondsToHumanUnitAgo(diff));
}

// TODO: This is for Storybook/jest.
// Longterm, this should be a utility function that can be imported.
// For the time being, duplication of this function is being avoided.
if (typeof globalThis !== 'undefined') {
  globalThis.timeAgo = timeAgo; // eslint-disable-line no-undef
}
