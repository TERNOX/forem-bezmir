const KYIV_LOCALE = 'uk-UA';
const KYIV_TIME_ZONE = 'Europe/Kyiv';

function formatDateTime(options, value) {
  return new Intl.DateTimeFormat(KYIV_LOCALE, {
    ...(options || {}),
    timeZone: KYIV_TIME_ZONE,
  }).format(value);
}

function convertUtcTime(utcTime) {
  const time = new Date(Number(utcTime));
  const options = {
    hour: '2-digit',
    minute: '2-digit',
    timeZoneName: 'short',
  };
  return formatDateTime(options, time);
}

function convertUtcDate(utcDate) {
  const date = new Date(Number(utcDate));
  const options = {
    month: 'long',
    day: 'numeric',
  };
  return formatDateTime(options, date);
}

function convertCalEvent(utc) {
  const date = new Date(Number(utc));
  const options = {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  };

  return formatDateTime(options, date);
}

function updateLocalDateTime(elements, convertCallback, getUtcDateTime) {
  let local;
  for (let i = 0; i < elements.length; i += 1) {
    local = convertCallback(getUtcDateTime(elements[i]));
    // eslint-disable-next-line no-param-reassign
    elements[i].innerHTML = local;
  }
}

function initializeTimeFixer() {
  const utcTime = document.getElementsByClassName('utc-time');
  const utcDate = document.getElementsByClassName('utc-date');
  const utc = document.getElementsByClassName('utc');

  if (!utc) {
    return;
  }

  updateLocalDateTime(
    utcTime,
    convertUtcTime,
    (element) => element.dataset.datetime,
  );
  updateLocalDateTime(
    utcDate,
    convertUtcDate,
    (element) => element.dataset.datetime,
  );
  updateLocalDateTime(utc, convertCalEvent, (element) => element.innerHTML);
}

export {
  initializeTimeFixer,
  updateLocalDateTime,
  convertUtcDate,
  convertUtcTime,
  formatDateTime,
  convertCalEvent,
};
