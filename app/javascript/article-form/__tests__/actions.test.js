import * as actions from '../actions';
import { processPayload, acceptedCoAuthorInvitees } from '../actions';
import { validateFileInputs } from '../../packs/validateFileInputs';
import { getVideoConfig, formatTemplate } from '../components/mediaConfig';

jest.mock('../../packs/validateFileInputs', () => ({
  validateFileInputs: jest.fn(),
}));

jest.mock('../components/mediaConfig', () => ({
  getVideoConfig: jest.fn(),
  formatTemplate: jest.fn(),
}));

describe('processVideoUpload', () => {
  let generateVideoUploadSpy;

  beforeEach(() => {
    validateFileInputs.mockReturnValue(true);
    getVideoConfig.mockReturnValue({
      limitMb: 50,
      limitBytes: 50 * 1024 * 1024,
      tooLargeMessageTemplate: 'template',
    });
    formatTemplate.mockReturnValue('friendly message');

    generateVideoUploadSpy = jest
      .spyOn(actions, 'generateVideoUpload')
      .mockImplementation(() => {});
  });

  afterEach(() => {
    generateVideoUploadSpy.mockRestore();
    jest.clearAllMocks();
    delete global.fetch;
    delete window.csrfToken;
  });

  it('surfaces an error when the video exceeds the configured size limit', () => {
    const failure = jest.fn();

    actions.processVideoUpload(
      [{ size: 60 * 1024 * 1024 }],
      jest.fn(),
      jest.fn(),
      failure,
    );

    expect(formatTemplate).toHaveBeenCalledWith('template', {
      size: '60.00',
      max: 50,
    });
    expect(failure).toHaveBeenCalledWith({ message: 'friendly message' });
    expect(generateVideoUploadSpy).not.toHaveBeenCalled();
    expect(validateFileInputs).not.toHaveBeenCalled();
  });

  it('aborts when the file inputs are invalid', () => {
    validateFileInputs.mockReturnValueOnce(false);
    const uploading = jest.fn();

    actions.processVideoUpload(
      [{ size: 10 * 1024 * 1024 }],
      uploading,
      jest.fn(),
      jest.fn(),
    );

    expect(uploading).not.toHaveBeenCalled();
    expect(generateVideoUploadSpy).not.toHaveBeenCalled();
  });

  it('dispatches the upload when the file fits within the limit', () => {
    // Restore the real generateVideoUpload and observe the actual request it
    // makes (spying the module export does not intercept the internal call).
    generateVideoUploadSpy.mockRestore();
    window.csrfToken = 'test-token';
    global.fetch = jest
      .fn()
      .mockResolvedValue({ json: () => Promise.resolve({}) });

    const uploading = jest.fn();
    const file = { size: 10 * 1024 * 1024 };

    actions.processVideoUpload([file], uploading, jest.fn(), jest.fn());

    expect(uploading).toHaveBeenCalledTimes(1);
    expect(global.fetch).toHaveBeenCalledWith(
      '/video_uploads',
      expect.objectContaining({ method: 'POST' }),
    );
  });
});

describe('processPayload', () => {
  const basePayload = {
    title: 'My Article',
    body_markdown: '# Hello World',
    tag_list: 'javascript, testing',
    organizationId: 42,
    coAuthorIdsList: '1,2',
  };

  const uiOnlyFields = {
    previewShowing: true,
    helpShowing: false,
    previewResponse: '<p>preview html</p>',
    helpHTML: '<p>help html</p>',
    imageManagementShowing: false,
    moreConfigShowing: true,
    errors: { title: ['is too short'] },
    organizations: [
      { id: 1, name: 'Org One', fetch_users_url: '/api/users?org=1' },
      { id: 2, name: 'Org Two', fetch_users_url: '/api/users?org=2' },
    ],
    authorId: 99,
    coAuthorsData: [{ id: 1, name: 'Co Author', username: 'coauthor' }],
  };

  it('preserves article content fields in the output', () => {
    const result = processPayload({ ...basePayload, ...uiOnlyFields });

    expect(result.title).toEqual('My Article');
    expect(result.body_markdown).toEqual('# Hello World');
    expect(result.tag_list).toEqual('javascript, testing');
    expect(result.organizationId).toEqual(42);
    expect(result.coAuthorIdsList).toEqual('1,2');
  });

  it('strips preview and help UI state fields', () => {
    const result = processPayload({ ...basePayload, ...uiOnlyFields });

    expect(result).not.toHaveProperty('previewShowing');
    expect(result).not.toHaveProperty('helpShowing');
    expect(result).not.toHaveProperty('previewResponse');
    expect(result).not.toHaveProperty('helpHTML');
  });

  it('strips modal/config UI state fields', () => {
    const result = processPayload({ ...basePayload, ...uiOnlyFields });

    expect(result).not.toHaveProperty('imageManagementShowing');
    expect(result).not.toHaveProperty('moreConfigShowing');
    expect(result).not.toHaveProperty('errors');
  });

  it('strips organizations array to prevent payload bloat', () => {
    const result = processPayload({ ...basePayload, ...uiOnlyFields });

    expect(result).not.toHaveProperty('organizations');
  });

  it('strips authorId which is UI-only context', () => {
    const result = processPayload({ ...basePayload, ...uiOnlyFields });

    expect(result).not.toHaveProperty('authorId');
  });

  it('strips coAuthorsData resolved user objects', () => {
    const result = processPayload({ ...basePayload, ...uiOnlyFields });

    expect(result).not.toHaveProperty('coAuthorsData');
  });

  describe('co-author invitations', () => {
    const invitationFields = {
      coAuthorInvitationsEnabled: true,
      coAuthorInvitationsMax: 4,
      coAuthorInvitations: [
        { id: 10, status: 'pending', user: { id: 7, username: 'ada' } },
      ],
      coAuthorInvitees: [
        { id: 7, username: 'ada' },
        { id: 8, username: 'grace' },
      ],
    };

    it('sends the invitee ids for a personal post', () => {
      const result = processPayload({
        ...basePayload,
        ...invitationFields,
        organizationId: null,
      });

      expect(result.coAuthorInviteeIds).toEqual([7, 8]);
    });

    it('sends an empty list when every invitee was removed', () => {
      const result = processPayload({
        ...basePayload,
        ...invitationFields,
        organizationId: '',
        coAuthorInvitees: [],
      });

      expect(result.coAuthorInviteeIds).toEqual([]);
    });

    it('leaves the list out for an organization post', () => {
      const result = processPayload({ ...basePayload, ...invitationFields });

      expect(result).not.toHaveProperty('coAuthorInviteeIds');
    });

    it('leaves the list out when invitations are disabled', () => {
      const result = processPayload({
        ...basePayload,
        ...invitationFields,
        organizationId: null,
        coAuthorInvitationsEnabled: false,
      });

      expect(result).not.toHaveProperty('coAuthorInviteeIds');
    });

    it('strips the invitation UI state', () => {
      const result = processPayload({
        ...basePayload,
        ...invitationFields,
        organizationId: null,
      });

      expect(result).not.toHaveProperty('coAuthorInvitationsEnabled');
      expect(result).not.toHaveProperty('coAuthorInvitationsMax');
      expect(result).not.toHaveProperty('coAuthorInvitations');
      expect(result).not.toHaveProperty('coAuthorInvitees');
    });
  });

  it('returns an empty-ish object when given only UI fields', () => {
    const result = processPayload(uiOnlyFields);

    // All UI-only keys should be gone
    const keys = Object.keys(result);
    const uiKeys = Object.keys(uiOnlyFields);
    uiKeys.forEach((key) => {
      expect(keys).not.toContain(key);
    });
  });

  it('handles a payload with none of the excluded fields present', () => {
    const result = processPayload({ ...basePayload });

    expect(result).toEqual(basePayload);
  });

  describe('acceptedCoAuthorInvitees', () => {
    const ada = { id: 7, name: 'Ada Lovelace', username: 'ada' };
    const grace = { id: 8, name: 'Grace Hopper', username: 'grace' };

    it('keeps only selected invitees whose invitation is accepted', () => {
      const invitations = [
        { id: 10, status: 'accepted', user: ada },
        { id: 11, status: 'pending', user: grace },
      ];

      expect(acceptedCoAuthorInvitees(invitations, [ada, grace])).toEqual([
        ada,
      ]);
      expect(acceptedCoAuthorInvitees(invitations, [grace])).toEqual([]);
    });
  });
});

describe('generateVideoUpload', () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    delete window.csrfToken;
    jest.clearAllMocks();
  });

  it('posts multipart FormData and does NOT force Content-Type: application/json', () => {
    // Regression: hardcoding application/json while sending FormData made the
    // server fail to parse the request (ActionDispatch ParseError), surfacing in
    // the editor as "Unexpected non-whitespace character after JSON".
    window.csrfToken = 'test-token';
    global.fetch = jest
      .fn()
      .mockResolvedValue({ json: () => Promise.resolve({}) });

    actions.generateVideoUpload({
      payload: { video: ['a-video-file'] },
      successCb: jest.fn(),
      failureCb: jest.fn(),
    });

    expect(global.fetch).toHaveBeenCalledTimes(1);
    const [url, options] = global.fetch.mock.calls[0];
    expect(url).toBe('/video_uploads');
    expect(options.method).toBe('POST');
    expect(options.body).toBeInstanceOf(FormData);
    expect(options.headers['X-CSRF-Token']).toBe('test-token');
    expect(options.headers['Content-Type']).toBeUndefined();
  });
});
