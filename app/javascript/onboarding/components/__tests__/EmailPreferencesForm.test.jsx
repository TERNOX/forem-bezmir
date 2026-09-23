import { h } from 'preact';
import { render, fireEvent, waitFor } from '@testing-library/preact';
import fetch from 'jest-fetch-mock';
import { axe } from 'jest-axe';

import { EmailPreferencesForm } from '../EmailPreferencesForm';

global.fetch = fetch;

describe('EmailPreferencesForm', () => {
  const renderEmailPreferencesForm = (next = jest.fn()) =>
    render(
      <EmailPreferencesForm
        next={next}
        prev={jest.fn()}
        currentSlideIndex={4}
        slidesCount={5}
        communityConfig={{
          communityName: 'Community Name',
          communityLogo: '/x.png',
          communityBackgroundColor: '#FFF000',
          communityDescription: 'Some community description',
        }}
        previousLocation={null}
      />,
    );

  const getUserData = () =>
    JSON.stringify({
      followed_tag_names: ['javascript'],
      profile_image_90: 'mock_url_link',
      name: 'firstname lastname',
      username: 'username',
    });

  const fakeResponse = JSON.stringify({
    content: `
    <h1>Almost there!</h1>
    <form>
      <fieldset>
        <ul>
          <li class="checkbox-item">
            <label for="email_newsletter"><input type="checkbox" id="email_newsletter" name="email_newsletter">I want to receive weekly newsletter emails.</label>
          </li>
        </ul>
      </fieldset>
    </form>
    `,
  });

  beforeEach(() => {
    fetch.resetMocks();
    fetch.mockResponseOnce(fakeResponse);
    localStorage.clear();
  });

  beforeAll(() => {
    document.head.innerHTML =
      '<meta name="csrf-token" content="some-csrf-token" />';
    document.body.setAttribute('data-user', getUserData());
  });

  it('should have no a11y violations', async () => {
    const { container } = render(renderEmailPreferencesForm());
    const results = await axe(container);

    expect(results).toHaveNoViolations();
  });

  it('should load the appropriate text', async () => {
    const { findByLabelText } = renderEmailPreferencesForm();
    await findByLabelText(/receive weekly newsletter/i);
    expect(document.body.innerHTML).toMatchSnapshot();
  });

  it('should show the checkbox unchecked', async () => {
    const { findByLabelText } = renderEmailPreferencesForm();
    const checkbox = await findByLabelText(/receive weekly newsletter/i);
    expect(checkbox.checked).toBe(false);
  });

  it('should render a stepper', () => {
    const { queryByTestId } = renderEmailPreferencesForm();
    expect(queryByTestId('stepper')).not.toBeNull();
  });

  it('should render a back button', () => {
    const { queryByTestId } = renderEmailPreferencesForm();
    expect(queryByTestId('back-button')).not.toBeNull();
  });

  it('should render a button that says Finish', () => {
    const { queryByText } = renderEmailPreferencesForm();
    expect(queryByText('Завершити')).not.toBeNull();
  });

  it('should show the reconsideration prompt when the checkbox is not checked', async () => {
    const { getByText, findByLabelText } = renderEmailPreferencesForm();
    await findByLabelText(/receive weekly newsletter/i);
    const finishButton = getByText('Завершити');

    fireEvent.click(finishButton);

    await waitFor(() => {
      expect(getByText(/Рекомендуємо підписатися на розсилку/i)).not.toBeNull();
    });
  });

  it('should handle "No thank you" button click in the reconsideration prompt', async () => {
    const next = jest.fn();
    const { getByText, findByLabelText } = renderEmailPreferencesForm(next);
    const checkbox = await findByLabelText(/receive weekly newsletter/i);
    const finishButton = getByText('Завершити');

    fireEvent.click(finishButton);

    await waitFor(() => {
      expect(getByText(/Рекомендуємо підписатися на розсилку/i)).not.toBeNull();
    });

    const noThankYouButton = getByText('Ні, дякую');
    fireEvent.click(noThankYouButton);

    await waitFor(() => expect(next).toHaveBeenCalledTimes(1));
    expect(fetch).toHaveBeenLastCalledWith('/onboarding/notifications',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify({ completed: true, notifications: { email_newsletter: false } }),
      }),
    );
    expect(localStorage.getItem('shouldRedirectToOnboarding')).toBe('false');
    expect(checkbox.checked).toBe(false);
  });

  it('stays on onboarding when saving the email opt-out fails', async () => {
    const next = jest.fn();
    const { getByText, findByLabelText } = renderEmailPreferencesForm(next);
    await findByLabelText(/receive weekly newsletter/i);
    fireEvent.click(getByText('Завершити'));
    fetch.mockResponseOnce('{}', { status: 422 });

    fireEvent.click(getByText('Ні, дякую'));

    await waitFor(() => expect(fetch).toHaveBeenLastCalledWith(
      '/onboarding/notifications', expect.any(Object),
    ));
    expect(next).not.toHaveBeenCalled();
    expect(localStorage.getItem('shouldRedirectToOnboarding')).toBeNull();
  });

  it('marks onboarding complete when accepting the newsletter immediately', async () => {
    const next = jest.fn();
    const { getByText, findByLabelText } = renderEmailPreferencesForm(next);
    const checkbox = await findByLabelText(/receive weekly newsletter/i);
    fireEvent.click(checkbox);

    fireEvent.click(getByText('Завершити'));

    await waitFor(() => expect(next).toHaveBeenCalledTimes(1));
    expect(fetch).toHaveBeenLastCalledWith('/onboarding/notifications', expect.objectContaining({
      body: JSON.stringify({ completed: true, notifications: { email_newsletter: true } }),
    }));
  });

  it('should handle "Count me in" button click in the reconsideration prompt', async () => {
    const { getByText, findByLabelText } = renderEmailPreferencesForm();
    await findByLabelText(/receive weekly newsletter/i);
    const finishButton = getByText('Завершити');

    fireEvent.click(finishButton);

    await waitFor(() => {
      expect(getByText(/Рекомендуємо підписатися на розсилку/i)).not.toBeNull();
    });

    const countMeInButton = getByText('Давайте спробую');
    fireEvent.click(countMeInButton);

    // Verify that the `finishWithEmail` function is called
    await waitFor(() => {
      expect(fetch).toHaveBeenCalledWith('/onboarding/notifications', expect.objectContaining({
        body: JSON.stringify({ completed: true, notifications: { email_newsletter: true, email_digest_periodic: true } }),
      }));
    });
  });
});
