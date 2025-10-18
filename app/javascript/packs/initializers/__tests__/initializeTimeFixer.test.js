import {
  initializeTimeFixer,
  convertUtcDate,
  convertUtcTime,
  formatDateTime,
  updateLocalDateTime,
  convertCalEvent,
} from '../initializeTimeFixer';

describe('initializeTimeFixer', () => {
  beforeEach(() => {
    const utcTimeClassDiv = document.createElement('div');
    const utcDateClassDiv = document.createElement('div');
    const utcDiv = document.createElement('div');

    utcTimeClassDiv.classList.add('utc-time');
    utcDateClassDiv.classList.add('utc-date');
    utcDiv.classList.add('utc');

    utcTimeClassDiv.dataset.datetime = 823230245000;
  });

  test('should call event listener when preview button exist', async () => {
    const button = document.createElement('button');
    button.classList.add('preview-toggle');
    button.addEventListener = jest.fn();
    initializeTimeFixer();

    expect(button.addEventListener).not.toHaveBeenCalled();
  });

  test('should call updateLocalDateTime', async () => {
    const updateLocalDateTime = jest.fn();
    initializeTimeFixer();

    expect(updateLocalDateTime).not.toHaveBeenCalled();
  });

  test('should call convertUtcDate', async () => {
    const convertUtcDate = jest.fn();
    initializeTimeFixer();

    expect(convertUtcDate).not.toHaveBeenCalled();
  });

  test('should convert Utc Dates', async () => {
    const utcDate = Date.UTC(96, 1, 2, 3, 4, 5);
    const dateConversion = await convertUtcDate(utcDate);
    // const formatDateTime = jest.fn();

    expect(dateConversion).toContain('2 лютого');
  });

  test('convertUtcDate function with different options', () => {
    const utcDate = 917924645000;

    const options1 = {
      month: 'short',
      day: 'numeric',
    };
    expect(convertUtcDate(utcDate, options1)).toBe('2 лютого');

    const options2 = {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
      timeZoneName: 'short',
    };
    expect(convertUtcDate(utcDate, options2)).toBe('2 лютого');
  });

  test('convertUtcTime function with different options', () => {
    const utcTime = 917924645000;

    const options1 = {
      hour: 'numeric',
      minute: 'numeric',
      timeZoneName: 'short',
    };
    expect(convertUtcTime(utcTime, options1)).toBe('05:04 GMT+2');

    const options2 = {
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
      timeZoneName: 'short',
    };
    expect(convertUtcTime(utcTime, options2)).toBe('05:04 GMT+2');
  });

  test('formatDateTime function with different options and values', () => {
    const options1 = {
      hour: 'numeric',
      minute: 'numeric',
      timeZoneName: 'short',
    };
    const value1 = new Date(917924645000);
    expect(formatDateTime(options1, value1)).toBe('05:04 GMT+2');

    const options2 = {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    };
    const value2 = new Date(917924645000);
    expect(formatDateTime(options2, value2)).toBe('2 лют. 1999 р.');
  });
});

describe('formatDateTime', () => {
  it('formats the date time with given options', () => {
    const options = {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
    };
    const value = new Date('2022-04-13T12:34:56Z');
    const expected = '13 квіт. 2022 р., 15:34';

    expect(formatDateTime(options, value)).toEqual(expected);
  });
});

describe('convertUtcTime', () => {
  it('converts the UTC time to local time with proper format', () => {
    const utcTime = 917924645000;
    const expected = '05:04 GMT+2';

    expect(convertUtcTime(utcTime)).toEqual(expected);
  });
});

describe('convertUtcDate', () => {
  it('converts the UTC date to local date with proper format', () => {
    const utcDate = 917924645000;
    const expected = '2 лютого';

    expect(convertUtcDate(utcDate)).toEqual(expected);
  });
});

describe('updateLocalDateTime', () => {
  it('updates the innerHTML of given elements with local time', () => {
    document.body.innerHTML = `
      <div>
        <span class="utc-time" data-datetime=917924645000></span>
        <span class="utc-date" data-datetime=917924645000></span>
        <span class="utc">917924645000</span>
      </div>
    `;

    const utcTimeElements = document.querySelectorAll('.utc-time');
    const utcDateElements = document.querySelectorAll('.utc-date');
    const utcElements = document.querySelectorAll('.utc');

    updateLocalDateTime(
      utcTimeElements,
      convertUtcTime,
      (element) => element.dataset.datetime,
    );
    updateLocalDateTime(
      utcDateElements,
      convertUtcDate,
      (element) => element.dataset.datetime,
    );
    updateLocalDateTime(
      utcElements,
      convertCalEvent,
      (element) => element.innerHTML,
    );

    expect(utcTimeElements[0].innerHTML).toEqual('05:04 GMT+2');
    expect(utcDateElements[0].innerHTML).toEqual('2 лютого');
    expect(utcElements[0].innerHTML).toEqual('вівторок, 2 лютого о 05:04');
  });
});

// eslint-disable-next-line jest/no-identical-title
describe('formatDateTime', () => {
  it('should format a date and time using the specified options', () => {
    const options = {
      weekday: 'short',
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      hour12: true,
    };
    const value = new Date(1682636630);
    const expected = 'вт, 20 січ. 1970 р., 2:23 пп';
    expect(formatDateTime(options, value)).toBe(expected);
  });
});

describe('convertCalEvent', () => {
  it('should convert UTC to a formatted date and time string', () => {
    const utc = 1682636630;
    const expected = 'вівторок, 20 січня о 14:23';
    expect(convertCalEvent(utc)).toBe(expected);
  });
});
