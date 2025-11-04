import { h } from 'preact';
import { useMemo, useState } from 'preact/hooks';
import PropTypes from 'prop-types';
import { generateVideoUpload } from '../actions';
import { validateFileInputs } from '../../packs/validateFileInputs';
import { addSnackbarItem } from '../../Snackbar';
import { getVideoConfig } from './mediaConfig';
import { ButtonNew as Button, Spinner } from '@crayons';
import VideoIcon from '@images/video-camera.svg';

export const VideoUploader = ({
  buttonProps = {},
  onVideoUploadStart,
  onVideoUploadSuccess,
  onVideoUploadError,
}) => {
  const [uploading, setUploading] = useState(false);
  const { limitMb: maxFileSize } = useMemo(() => getVideoConfig(), []);

  const handleError = (error) => {
    const message = error?.message || error;
    addSnackbarItem({
      message,
      addCloseButton: true,
    });
    onVideoUploadError?.();
    setUploading(false);
  };

  const handleSuccess = (response) => {
    setUploading(false);
    const link = response.links[0];
    const markdown = (response.markdown || `![](${link})`).trim();
    onVideoUploadSuccess?.(`${markdown}\n`);
  };

  const uploadVideo = (files) => {
    if (files.length === 0 || !validateFileInputs()) {
      return;
    }

    setUploading(true);
    onVideoUploadStart?.();

    generateVideoUpload({
      payload: { video: files },
      successCb: handleSuccess,
      failureCb: handleError,
    });
  };

  return (
    <span className="video-uploader">
      <input
        type="file"
        id="video-upload-field"
        className="screen-reader-only"
        accept="video/mp4,video/webm,video/quicktime"
        data-permitted-file-types='["video"]'
        data-max-file-size-mb={maxFileSize}
        onChange={(event) => uploadVideo(event.target.files)}
      />
      <Button
        {...buttonProps}
        icon={uploading ? Spinner : VideoIcon}
        aria-label={`Завантажити відео (max ${maxFileSize} MB)`}
        onClick={(event) => {
          buttonProps.onClick?.(event);
          document.getElementById('video-upload-field').click();
        }}
        disabled={uploading}
      />
    </span>
  );
};

VideoUploader.propTypes = {
  buttonProps: PropTypes.object,
  onVideoUploadStart: PropTypes.func,
  onVideoUploadSuccess: PropTypes.func,
  onVideoUploadError: PropTypes.func,
};

VideoUploader.displayName = 'VideoUploader';
