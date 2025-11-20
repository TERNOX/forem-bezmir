import { initializeSteamIframeColorScheme } from '../liquidTags/steamIframe';
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
import { initializeSpoilers } from './initializers/initializeSpoilers';

initializeCommentDate();
initializeCommentPreview();
initializeSettings();
initializeNotifications();
initializeTimeFixer();
initializeDateHelpers();
initializeGifVideos(document);
initializeSpoilers();
initializeSteamIframeColorScheme();

InstantClick.on('change', () => {
  initializeCommentDate();
  initializeCommentPreview();
  initializeSettings();
  initializeNotifications();
  initializeGifVideos(document);
  initializeSpoilers();
  initializeSteamIframeColorScheme();
});

window.showUserAlertModal = showUserAlertModal;
window.showModalAfterError = showModalAfterError;
