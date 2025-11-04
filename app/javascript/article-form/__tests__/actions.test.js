import * as actions from '../actions';
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
    const uploading = jest.fn();
    const success = jest.fn();
    const failure = jest.fn();
    const file = { size: 10 * 1024 * 1024 };

    actions.processVideoUpload([file], uploading, success, failure);

    expect(uploading).toHaveBeenCalledTimes(1);
    expect(generateVideoUploadSpy).toHaveBeenCalledWith({
      payload: { video: [file] },
      successCb: success,
      failureCb: failure,
    });
  });
});
