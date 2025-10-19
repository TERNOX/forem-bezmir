/* Local date/time utilities */

/*
  Convert string timestamp to local time, using the given locale.

  timestamp should be something like '2019-05-03T16:02:50.908Z'
  locale can be `navigator.language` or a custom locale. defaults to 'uk-UA'
  options are `Intl.DateTimeFormat` options

  see <https://developer.mozilla.org//docs/Web/JavaScript/Reference/Global_Objects/DateTimeFormat>
  for more information.
*/
const DEFAULT_LOCALE = 'uk';
const KYIV_TIME_ZONE = 'Europe/Kyiv';

export function timestampToLocalDateTime(timestamp, locale, options) {
  if (!timestamp) {
    return '';
  }

  try {
    const time = new Date(timestamp);
    const formatOptions = { ...(options || {}), timeZone: KYIV_TIME_ZONE };
    const formattedTime = new Intl.DateTimeFormat(
      locale || DEFAULT_LOCALE,
      formatOptions,
    ).format(time);
    return options.year === '2-digit'
      ? formattedTime.replace(', ', " '")
      : formattedTime;
  } catch (e) {
    return '';
  }
}

export function addLocalizedDateTimeToElementsTitles(elements, timestampAttribute) {
  for (let i = 0; i < elements.length; i += 1) {
    const element = elements[i];

    // get UTC timestamp set by the server
    const timestamp = element.getAttribute(timestampAttribute || 'datetime');

    if (timestamp) {
      // add a full datetime to the element title, visible on hover.
      // Kyiv locale and timezone keep the display consistent across the UI.
      const localDateTime = timestampToLocalDateTimeLong(timestamp);
      element.setAttribute('title', localDateTime);
    }
  }
}

export function localizeTimeElements(elements, timeOptions) {
  for (let i = 0; i < elements.length; i += 1) {
    const element = elements[i];

    const timestamp = element.getAttribute('datetime');
    if (timestamp) {
      const localDateTime = timestampToLocalDateTime(
        timestamp,
        DEFAULT_LOCALE,
        timeOptions,
      );

      element.textContent = localDateTime;
    }
  }
}

function timestampToLocalDateTimeLong(timestamp) {
  // example: "середа, 3 квітня 2019 р., 17:55:14"

  return timestampToLocalDateTime(timestamp, DEFAULT_LOCALE, {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
  });
}

function timestampToLocalDateTimeShort(timestamp) {
  // example: "10 грудня 2018 р., 19:30" if it is not the current year
  // example: "6 вересня, 08:15" if it is the current year

  if (timestamp) {
    const currentYear = new Date().getFullYear();
    const givenYear = new Date(timestamp).getFullYear();

    const timeOptions = {
      day: 'numeric',
      month: 'long',
      hour: '2-digit',
      minute: '2-digit',
    };

    if (givenYear !== currentYear) {
      timeOptions.year = 'numeric';
    }

    return timestampToLocalDateTime(timestamp, DEFAULT_LOCALE, timeOptions);
  }

  return '';
}

if (typeof globalThis !== 'undefined') {
  globalThis.timestampToLocalDateTimeLong = timestampToLocalDateTimeLong; // eslint-disable-line no-undef
  globalThis.timestampToLocalDateTimeShort = timestampToLocalDateTimeShort; // eslint-disable-line no-undef
}
