import { h, Fragment } from 'preact';
import { useState, useCallback, useRef, useEffect } from 'preact/hooks';
import PropTypes from 'prop-types';
import moment from 'moment';
import { SeriesSelector } from './SeriesSelector';
import { CoAuthorSelector } from './CoAuthorSelector';
import { Modal, ButtonNew as Button } from '@crayons';
import CogIcon from '@images/cog.svg';

/**
 * Component comprising a trigger button and dropdown with additional post options.
 *
 * @param {Object} props
 * @param {Object} props.passedData The current post options data
 * @param {Function} props.onSaveDraft Callback for when the post draft is saved
 * @param {Function} props.onConfigChange Callback for when the config options have changed
 */

export const Options = ({
  passedData: {
    published = false,
    publishedAtDate = '',
    publishedAtTime = '',
    publishedAtWas = '',
    timezone = Intl.DateTimeFormat().resolvedOptions().timeZone,
    allSeries = [],
    canonicalUrl = '',
    series = '',
    organizationId = null,
    organizations = [],
    authorId = null,
    coAuthorIdsList = '',
  },
  schedulingEnabled: _schedulingEnabled, // Deprecated - scheduling is always enabled now
  onSaveDraft,
  onConfigChange,
  previewLoading,
  externalOpenSignal = 0,
}) => {
  const [isOptionsModalOpen, setIsOptionsModalOpen] = useState(false);
  const [seriesShowCreateForm, setSeriesShowCreateForm] = useState(false);
  const modalContentRef = useRef(null);
  
  // Stable close handler to prevent re-renders from causing modal to close
  const handleModalClose = useCallback(() => {
    setIsOptionsModalOpen(false);
    setSeriesShowCreateForm(false);
  }, []);

  // Open the modal when parent triggers a new external signal
  useEffect(() => {
    if (externalOpenSignal > 0) {
      setIsOptionsModalOpen(true);
    }
  }, [externalOpenSignal]);

  // Wrap onConfigChange to prevent modal from closing when state updates
  const handleConfigChangeWithModalOpen = useCallback((e) => {
    if (e && typeof e.preventDefault === 'function') {
      e.preventDefault();
    }
    if (e && typeof e.stopPropagation === 'function') {
      e.stopPropagation();
    }
    onConfigChange(e);
  }, [onConfigChange]);

  let publishedField = '';
  let publishedAtField = '';

  const wasScheduled = publishedAtWas && moment(publishedAtWas) > moment();
  const editablePublishedAt = !publishedAtWas || wasScheduled;

  if (published) {
    if (wasScheduled) {
      publishedField = (
        <div data-testid="options__danger-zone" className="crayons-field mb-6">
          <Button
            className="c-btn c-btn--secondary w-100"
            variant="primary"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onSaveDraft(e);
            }}
          >
            Перетворити на чернетку
          </Button>
        </div>
      );
    } else {
      publishedField = (
        <div data-testid="options__danger-zone" className="crayons-field mb-6">
          <div className="crayons-field__label color-accent-danger">Небезпечна зона</div>
          <Button 
            variant="primary" 
            destructive 
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              onSaveDraft(e);
            }}
          >
            Скасувати публікацію
          </Button>
        </div>
      );
    }
  }

  // Always show scheduling (removed feature flag check)
  if (editablePublishedAt) {
    const currentDate = moment().format('YYYY-MM-DD');
    const localTime = moment().format('h:mm A');
    const localDate = moment().format('MMMM D, YYYY');
    const hasSchedule = publishedAtDate && publishedAtTime;
    const scheduleMoment = hasSchedule ? moment(`${publishedAtDate} ${publishedAtTime}`) : null;
    const isFutureSchedule = scheduleMoment && scheduleMoment > moment();

    publishedAtField = (
      <div className={`crayons-field mb-6 ${hasSchedule ? 'post-options-scheduling--active' : ''}`}>
        <label htmlFor="publishedAtDate" className="crayons-field__label">
          Запланувати публікацію
        </label>
        <p className="crayons-field__description mb-3">
          Встановіть дату й час для майбутньої публікації. Залиште порожнім, щоб опублікувати одразу.
        </p>
        <div className="flex gap-3 mb-3">
          <div className="flex-1">
            <label htmlFor="publishedAtDate" className="crayons-field__label crayons-field__label--small mb-1">
              Дата
            </label>
            <input
              aria-label="Schedule publication date"
              type="date"
              min={currentDate}
              value={publishedAtDate}
              className="crayons-textfield"
              name="publishedAtDate"
              onChange={handleConfigChangeWithModalOpen}
              onClick={(e) => e.stopPropagation()}
              onMouseDown={(e) => e.stopPropagation()}
              id="publishedAtDate"
            />
          </div>
          <div className="flex-1">
            <label htmlFor="publishedAtTime" className="crayons-field__label crayons-field__label--small mb-1">
              Час
            </label>
            <input
              aria-label="Schedule publication time"
              type="time"
              value={publishedAtTime}
              className="crayons-textfield"
              name="publishedAtTime"
              onChange={handleConfigChangeWithModalOpen}
              onClick={(e) => e.stopPropagation()}
              onMouseDown={(e) => e.stopPropagation()}
              id="publishedAtTime"
            />
          </div>
        </div>
        {hasSchedule && isFutureSchedule && (
          <div className="py-3 rounded-lg border border-accent-brand bg-accent-brand-bg mb-3">
            <p className="crayons-field__description mb-0">
              <strong>Допис буде опублікований:</strong> {scheduleMoment.format('MMMM D, YYYY [о] h:mm A')}
            </p>
          </div>
        )}
        <input
          type="hidden"
          value={timezone}
          name="timezone"
          id="timezone"
        />
        <div className="crayons-field__description">
          Використовується ваш локальний часовий пояс: <strong>{timezone}</strong>. Поточний час: <strong>{localTime}</strong> — <strong>{localDate}</strong>.
        </div>
        {hasSchedule && (
          <Button
            variant="secondary"
            type="button"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              const clearDateEvent = {
                target: {
                  name: 'publishedAtDate',
                  value: '',
                },
                preventDefault: () => {},
              };
              const clearTimeEvent = {
                target: {
                  name: 'publishedAtTime',
                  value: '',
                },
                preventDefault: () => {},
              };
              handleConfigChangeWithModalOpen(clearDateEvent);
              handleConfigChangeWithModalOpen(clearTimeEvent);
            }}
            className="mt-2"
          >
            Очистити розклад
          </Button>
        )}
      </div>
    );
  }

  return (
    <Fragment>
      <span className="mx-2 color-base-30" aria-hidden="true">|</span>
      <Button
        id="post-options-btn"
        icon={CogIcon}
        title="Розширені налаштування допису"
        aria-label="Розширені налаштування допису"
        disabled={previewLoading}
        onClick={() => setIsOptionsModalOpen(true)}
      >
        <span className="hidden l:inline-block ml-1">Advanced Options</span>
      </Button>
      {isOptionsModalOpen && (
        <Modal
          title="Розширені налаштування допису"
          onClose={handleModalClose}
          size="large"
          backdropDismissible
          className="post-options-modal"
        >
          <div className="post-options-modal__wrapper">
            <div 
              className="post-options-modal__content"
              ref={modalContentRef}
            >
              <div className="crayons-field mb-6">
                <label htmlFor="canonicalUrl" className="crayons-field__label">
                  Канонічний URL
                </label>
                <p className="crayons-field__description">
                  Вкажіть посилання на оригінал, якщо публікуєте статтю з іншого місця (наприклад, зі свого блогу).
                </p>
                <input
                  type="text"
                  value={canonicalUrl}
                  className="crayons-textfield"
                  placeholder="https://yoursite.com/post-title"
                  name="canonicalUrl"
                  onKeyUp={handleConfigChangeWithModalOpen}
                  onInput={handleConfigChangeWithModalOpen}
                  onClick={(e) => e.stopPropagation()}
                  onMouseDown={(e) => e.stopPropagation()}
                  id="canonicalUrl"
                />
              </div>

              {publishedAtField}

              <div className={`crayons-field mb-6 ${series ? 'post-options-series--active' : ''}`}>
                <label htmlFor="series" className="crayons-field__label">
                  Серія
                </label>
                <p className="crayons-field__description mb-4">
                  Об’єднайте свої дописи в серію, щоб читачам було легше знаходити пов’язані статті.
                </p>
                <SeriesSelector
                  allSeries={allSeries}
                  currentSeries={series}
                  organizationId={organizationId}
                  onSelectSeries={handleConfigChangeWithModalOpen}
                  onCreateSeries={handleConfigChangeWithModalOpen}
                  showCreateForm={seriesShowCreateForm}
                  onShowCreateFormChange={setSeriesShowCreateForm}
                />
              </div>

              <CoAuthorSelector
                authorId={authorId}
                coAuthorIdsList={coAuthorIdsList}
                organizationId={organizationId}
                organizations={organizations}
                onConfigChange={handleConfigChangeWithModalOpen}
              />

              {publishedField}
            </div>
            <div className="post-options-modal__footer">
              <Button
                variant="primary"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  handleModalClose();
                }}
              >
                Готово
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </Fragment>
  );
};

Options.propTypes = {
  passedData: PropTypes.shape({
    published: PropTypes.bool.isRequired,
    publishedAtDate: PropTypes.string.isRequired,
    publishedAtTime: PropTypes.string.isRequired,
    publishedAtWas: PropTypes.string.isRequired,
    timezone: PropTypes.string.isRequired,
    allSeries: PropTypes.array.isRequired,
    canonicalUrl: PropTypes.string.isRequired,
    series: PropTypes.string.isRequired,
    organizations: PropTypes.array.isRequired,
    authorId: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    coAuthorIdsList: PropTypes.string,
    organizationId: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
  }).isRequired,
  schedulingEnabled: PropTypes.bool, // Kept for backward compatibility but no longer used
  onSaveDraft: PropTypes.func.isRequired,
  onConfigChange: PropTypes.func.isRequired,
  previewLoading: PropTypes.bool.isRequired,
  externalOpenSignal: PropTypes.number,
};

Options.displayName = 'Налаштування';
