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

describe('VotingApp results places', () => {
  const ranked = {
    ...category,
    id: 2,
    title: 'Best story',
    maxChoices: 3,
    ranked: true,
    points: [3, 2, 1],
    nominees: [
      { id: 20, title: 'Hades', imageUrl: null },
      { id: 21, title: 'Clair', imageUrl: null },
      { id: 22, title: 'Silksong', imageUrl: null },
      { id: 23, title: 'Nobody picked me', imageUrl: null },
    ],
  };
  const plain = {
    ...category,
    nominees: [
      { id: 10, title: 'Doom', imageUrl: null },
      { id: 11, title: 'Tetris', imageUrl: null },
    ],
  };
  const placesResults = {
    ballotsCount: 2,
    categories: {
      1: {
        voters: 2,
        rows: [
          {
            nomineeId: 10,
            place: 1,
            points: 1,
            votes: 1,
            firsts: 0,
            share: 100,
          },
          {
            nomineeId: 11,
            place: 1,
            points: 1,
            votes: 1,
            firsts: 0,
            share: 100,
          },
        ],
      },
      2: {
        voters: 2,
        rows: [
          {
            nomineeId: 20,
            place: 1,
            points: 4,
            votes: 2,
            firsts: 1,
            share: 100,
          },
          {
            nomineeId: 21,
            place: 1,
            points: 4,
            votes: 2,
            firsts: 1,
            share: 100,
          },
          {
            nomineeId: 22,
            place: 3,
            points: 4,
            votes: 2,
            firsts: 0,
            share: 100,
          },
          {
            nomineeId: 23,
            place: null,
            points: 0,
            votes: 0,
            firsts: 0,
            share: 0,
          },
        ],
      },
    },
  };

  function renderResults() {
    return render(
      <VotingApp
        voting={{
          slug: 'goty',
          status: 'closed',
          ballotUrl: '/vote/goty/ballot',
        }}
        categories={[plain, ranked]}
        results={placesResults}
        strings={{
          points: 'Points: %{count}',
          votes: 'Votes: %{count}',
          first_places: '1st places: %{count}',
          ranked_tie_hint: 'More first places win a points tie.',
        }}
        signInUrl="/enter"
      />,
    );
  }

  function placeOf(title) {
    const row = screen.getByText(title).closest('.voting-results__row');
    return row.querySelector('.voting-results__place').textContent;
  }

  beforeEach(() => {
    request.mockResolvedValue({
      json: () =>
        Promise.resolve({ signedIn: false, eligible: false, ballot: null }),
    });
  });

  it('gives the trophy to every row in first place and to no one else', async () => {
    renderResults();
    await waitFor(() => expect(request).toHaveBeenCalled());

    expect(placeOf('Hades')).toBe('🏆');
    expect(placeOf('Clair')).toBe('🏆');
    expect(placeOf('Silksong')).toBe('3');
    expect(placeOf('Nobody picked me')).toBe('—');
    expect(placeOf('Doom')).toBe('🏆');
    expect(placeOf('Tetris')).toBe('🏆');
    expect(
      screen
        .getByText('Silksong')
        .closest('.voting-results__row')
        .classList.contains('voting-results__row--winner'),
    ).toBe(false);
  });

  it('shows first places and the tie hint only for ranked nominations', async () => {
    const { container } = renderResults();
    await waitFor(() => expect(request).toHaveBeenCalled());

    const sections = container.querySelectorAll('.voting-results__category');
    const [plainSection, rankedSection] = sections;
    expect(plainSection.textContent).not.toContain('1st places');
    expect(plainSection.textContent).not.toContain('More first places');
    const firstsOf = (title) =>
      screen
        .getByText(title)
        .closest('.voting-results__row')
        .querySelector('.voting-results__firsts').textContent;
    expect(firstsOf('Hades')).toBe('1st places: 1');
    expect(firstsOf('Silksong')).toBe('1st places: 0');
    expect(rankedSection.textContent).toContain(
      'More first places win a points tie.',
    );
  });
});

describe('VotingApp thanks view', () => {
  const shareUrl = '/vote/goty/u/alice/abc123';

  beforeEach(() => {
    window.HTMLElement.prototype.scrollIntoView = jest.fn();
    request.mockImplementation((_url, options) =>
      Promise.resolve(
        options.method === 'PUT'
          ? {
              ok: true,
              json: () =>
                Promise.resolve({
                  ballot: {
                    submittedAt: '2026-11-22T12:00:00Z',
                    selections: { 1: { nominee_ids: [10], other: null } },
                  },
                  shareUrl,
                }),
            }
          : {
              json: () =>
                Promise.resolve({
                  signedIn: true,
                  eligible: true,
                  ballot: null,
                }),
            },
      ),
    );
  });

  it('shows the portrait vote card at its own ratio once it has loaded', async () => {
    const { container } = renderApp('open', null);
    await waitFor(() => expect(request).toHaveBeenCalled());

    fireEvent.click(screen.getByRole('button', { name: 'Clair' }));
    fireEvent.click(screen.getByRole('button', { name: /to_summary/ }));
    const submit = screen.getByRole('button', { name: 'submit' });
    await waitFor(() => expect(submit).not.toBeDisabled());
    fireEvent.click(submit);

    const image = await screen.findByAltText('share_image_alt');
    expect(image).toHaveAttribute('src', `${shareUrl}/image?attempt=0`);
    expect(image).not.toHaveAttribute('width');
    expect(image).not.toHaveAttribute('height');
    const preview = container.querySelector('.voting-share__preview');
    expect(preview).toHaveClass('voting-share__preview--loading');
    expect(screen.getByText('image_generating')).toBeInTheDocument();

    fireEvent.load(image);
    expect(preview).not.toHaveClass('voting-share__preview--loading');
    expect(screen.queryByText('image_generating')).not.toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: 'share_download' }),
    ).toHaveAttribute('href', `${shareUrl}/image`);
  });
});
