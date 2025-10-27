import { initializeSteamIframeColorScheme } from '../liquidTags/steamIframe';
import { initializeYoutubeIframeLazyLoad } from '../liquidTags/youtubeIframe';
import { initializeCommentDate } from './initializers/initializeCommentDate';
import { initializeCommentPreview } from './initializers/initializeCommentPreview';
import { initializeTimeFixer } from './initializers/initializeTimeFixer';
import { initializeNotifications } from './initializers/initializeNotifications';
import { initializeDateHelpers } from './initializers/initializeDateTimeHelpers';
import { initializeSettings } from './initializers/initializeSettings';
import { initializeGifVideos } from '@utilities/gifVideo';
import {
  showUserAlertModal,
  showModalAfterError,
} from '@utilities/showUserAlertModal';

initializeCommentDate();
initializeCommentPreview();
initializeSettings();
initializeNotifications();
initializeTimeFixer();
initializeDateHelpers();
initializeGifVideos(document);
initializeSteamIframeColorScheme();
initializeYoutubeIframeLazyLoad();

InstantClick.on('change', () => {
  initializeCommentDate();
  initializeCommentPreview();
  initializeSettings();
  initializeNotifications();
  initializeGifVideos(document);
  initializeSteamIframeColorScheme();
  initializeYoutubeIframeLazyLoad();
});

window.showUserAlertModal = showUserAlertModal;
window.showModalAfterError = showModalAfterError;
