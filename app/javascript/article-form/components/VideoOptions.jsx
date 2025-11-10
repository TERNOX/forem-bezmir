import { h } from 'preact';
import { useCallback } from 'preact/hooks';
import PropTypes from 'prop-types';
import { Dropdown, ButtonNew as Button } from '@crayons';
import VideoIcon from '@images/video-camera.svg';
import { VideoUploader } from './VideoUploader';

export const VideoOptions = ({
  passedData: { video = '', videoSourceUrl = '' },
  onConfigChange,
  onConfigValueChange,
  previewLoading,
}) => {
  const handleVideoSourceInput = useCallback(
    (event) => {
      onConfigChange(event);
      if (video) {
        onConfigValueChange('video', '');
      }
    },
    [onConfigChange, onConfigValueChange, video],
  );

  const handleVideoUploadSuccess = useCallback(
    (_, link) => {
      if (!link) {
        return;
      }
      onConfigValueChange('video', link);
      onConfigValueChange('videoSourceUrl', '');
    },
    [onConfigValueChange],
  );

  const handleVideoUploadStart = useCallback(() => {
    onConfigValueChange('videoSourceUrl', '');
  }, [onConfigValueChange]);

  const handleVideoUploadError = useCallback(() => {}, []);

  const clearVideoSelection = useCallback(() => {
    onConfigValueChange('video', '');
    onConfigValueChange('videoSourceUrl', '');
  }, [onConfigValueChange]);

  return (
    <div className="s:relative">
      <Button
        id="video-options-btn"
        icon={VideoIcon}
        title="Налаштування відео"
        aria-label="Video options"
        disabled={previewLoading}
      >
        Відео-допис
      </Button>
      <Dropdown
        triggerButtonId="video-options-btn"
        dropdownContentId="video-options-dropdown"
        dropdownContentCloseButtonId="video-options-done-btn"
        className="reverse left-2 s:left-0 right-2 s:left-auto p-4"
      >
        <h3 className="mb-6">Відео-допис</h3>
        <p className="crayons-field__description mb-6">
          Додайте відео як обкладинку допису. Ви можете вказати посилання на YouTube або завантажити власне відео.
        </p>
        <div className="crayons-field mb-6">
          <label htmlFor="videoSourceUrl" className="crayons-field__label">
            Посилання на YouTube
          </label>
          <p className="crayons-field__description">
            Вставте повне посилання на ролик. Після збереження обкладинкою стане вбудоване відео з YouTube.
          </p>
          <input
            type="url"
            value={videoSourceUrl}
            className="crayons-textfield"
            name="videoSourceUrl"
            id="videoSourceUrl"
            placeholder="https://www.youtube.com/watch?v=..."
            onInput={handleVideoSourceInput}
          />
        </div>
        <div className="crayons-field mb-6">
          <label htmlFor="video-cover-upload" className="crayons-field__label">
            Завантажити відео-обкладинку
          </label>
          <p className="crayons-field__description">
            Завантажене відео буде використано як обкладинка цього допису.
          </p>
          <VideoUploader
            onVideoUploadStart={handleVideoUploadStart}
            onVideoUploadSuccess={handleVideoUploadSuccess}
            onVideoUploadError={handleVideoUploadError}
            buttonProps={{
              id: 'video-cover-upload',
              className: 'w-100',
              variant: 'secondary',
              disabled: previewLoading,
              type: 'button',
              children: 'Завантажити відео',
            }}
          />
          {(video || videoSourceUrl) && (
            <p className="crayons-field__description mt-2 break-all">
              Поточне відео: {videoSourceUrl || video}
            </p>
          )}
        </div>
        {(video || videoSourceUrl) && (
          <Button
            className="w-100 mb-4"
            variant="ghost"
            onClick={clearVideoSelection}
            type="button"
          >
            Очистити відео
          </Button>
        )}
        <Button
          id="video-options-done-btn"
          className="w-100"
          data-content="exit"
          variant="secondary"
          type="button"
        >
          Готово
        </Button>
      </Dropdown>
    </div>
  );
};

VideoOptions.propTypes = {
  passedData: PropTypes.shape({
    video: PropTypes.string,
    videoSourceUrl: PropTypes.string,
    videoThumbnailUrl: PropTypes.string,
  }).isRequired,
  onConfigChange: PropTypes.func.isRequired,
  onConfigValueChange: PropTypes.func.isRequired,
  previewLoading: PropTypes.bool.isRequired,
};

VideoOptions.displayName = 'VideoOptions';
