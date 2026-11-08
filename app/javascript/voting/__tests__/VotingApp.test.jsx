import { h } from 'preact';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import '@testing-library/jest-dom';
import { VotingApp } from '../VotingApp';
import { request } from '@utilities/http';

jest.mock('@utilities/http', () => ({ request: jest.fn() }));

const category = {
  id: 1,
  title: 'Game of the Year',
  maxChoices: 1,
  ranked: false,
  required: false,
  allowOther: false,
  points: [],
  nominees: [{ id: 10, title: 'Clair', imageUrl: null }],
};

const results = {
  ballotsCount: 3,
  categories: { 1: { rows: [{ nomineeId: 10, title: 'Clair', points: 3 }] } },
};

function renderApp(status, publishedResults) {
  return render(
    <VotingApp
      voting={{ slug: 'goty', status, ballotUrl: '/vote/goty/ballot' }}
      categories={[category]}
      results={publishedResults}
      strings={{}}
      signInUrl="/enter"
    />,
  );
}

describe('VotingApp results access', () => {
  beforeEach(() => {
    request.mockResolvedValue({
      json: () =>
        Promise.resolve({ signedIn: false, eligible: false, ballot: null }),
    });
  });

  it('lets people open published results while voting is still open', async () => {
    renderApp('open', results);
    await waitFor(() => expect(request).toHaveBeenCalled());

    fireEvent.click(screen.getByRole('button', { name: 'show_results' }));
    expect(screen.getByText('results_title')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'back_to_voting' }));
    expect(screen.queryByText('results_title')).not.toBeInTheDocument();
  });

  it('opens on the results once a closed voting has them', async () => {
    renderApp('closed', results);
    await waitFor(() => expect(request).toHaveBeenCalled());

    expect(screen.getByText('results_title')).toBeInTheDocument();
  });

  it('offers no results button until they are published', async () => {
    renderApp('open', null);
    await waitFor(() => expect(request).toHaveBeenCalled());

    expect(
      screen.queryByRole('button', { name: 'show_results' }),
    ).not.toBeInTheDocument();
  });
});
