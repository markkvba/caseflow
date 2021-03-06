import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';
import { css } from 'glamor';
import _ from 'lodash';

import AppSegment from '@department-of-veterans-affairs/caseflow-frontend-toolkit/components/AppSegment';
import Alert from '../../components/Alert';
import Link from '@department-of-veterans-affairs/caseflow-frontend-toolkit/components/Link';
import { LockModal, RemoveHearingModal, DispositionModal } from './DailyDocketModals';
import StatusMessage from '../../components/StatusMessage';
import { getHearingAppellantName } from './DailyDocketRowDisplayText';

import DailyDocketRows from './DailyDocketRows';
import DailyDocketEditLinks from './DailyDocketEditLinks';

const alertStyling = css({
  marginBottom: '30px'
});

const Alerts = ({
  saveSuccessful, displayLockSuccessMessage, onErrorHearingDayLock, dailyDocket, dailyDocketServerError,
  user
}) => (
  <React.Fragment>
    {user.userRoleHearingPrep &&
      <Alert type="info"
        styling={alertStyling}
        title="New Hearing Schedule View"
        message={<span><p>{'We\'re piloting an updated version of caseflow hearing. ' +
          'Try it out and provide any feedback through our support channels. ' +
          'Note: travel board is not supported in the updated version.'}</p><p>
          <Link button href="/hearings/dockets"><span {...css({ color: '#fff' })}>Return to old view</span></Link>
        </p></span>} />}

    {saveSuccessful &&
      <Alert type="success"
        styling={alertStyling}
        title={`You have successfully updated ${getHearingAppellantName(saveSuccessful)}'s hearing.`} />}

    {displayLockSuccessMessage &&
      <Alert type="success"
        styling={alertStyling}
        title={dailyDocket.lock ? 'You have successfully locked this Hearing ' +
          'Day' : 'You have successfully unlocked this Hearing Day'}
        message={dailyDocket.lock ? 'You cannot add more veterans to this hearing day, ' +
          'but you can edit existing entries' : 'You can now add more veterans to this hearing day'} />}

    {dailyDocketServerError &&
      <Alert type="error"
        styling={alertStyling}
        title=" This save was unsuccessful."
        message="Please refresh the page and try again." />}

    {onErrorHearingDayLock &&
      <Alert type="error"
        styling={alertStyling}
        title={`VACOLS Hearing Day ${moment(dailyDocket.scheduledFor).format('M/DD/YYYY')}
           cannot be locked in Caseflow.`}
        message="VACOLS Hearing Day cannot be locked" />}
  </React.Fragment>
);

export default class DailyDocket extends React.Component {
  constructor (props) {
    super(props);

    this.state = {
      editedDispositionModalProps: null
    };
  }
  onInvalidForm = (hearingId) => (invalid) => this.props.onInvalidForm(hearingId, invalid);

  previouslyScheduled = (hearing) => {
    return hearing.disposition === 'postponed' || hearing.disposition === 'cancelled';
  };

  previouslyScheduledHearings = () => {
    return _.filter(this.props.hearings, (hearing) => this.previouslyScheduled(hearing));
  };

  dailyDocketHearings = () => {
    return _.filter(this.props.hearings, (hearing) => !this.previouslyScheduled(hearing));
  };

  getRegionalOffice = () => {
    const { dailyDocket } = this.props;

    return dailyDocket.requestType === 'Central' ? 'C' : dailyDocket.regionalOfficeKey;
  };

  openDispositionModal = ({ hearing, disposition, onConfirm }) => {
    this.setState({
      editedDispositionModalProps: {
        hearing,
        disposition,
        onConfirm: () => {
          onConfirm();
          this.closeDispositionModal();
        }
      }
    });
  }

  closeDispositionModal = () => {
    this.setState({ editedDispositionModalProps: null });
  }

  saveHearing = (hearingId) => {
    setTimeout(() => {
      // this ensures we're updating with the latest hearing data
      // after Redux update
      const hearing = this.props.hearings[hearingId];

      this.props.saveHearing(hearing);
    }, 0);
  }

  render() {

    const regionalOffice = this.getRegionalOffice();
    const docketHearings = this.dailyDocketHearings();
    const prevHearings = this.previouslyScheduledHearings();

    const hasHearings = !_.isEmpty(this.props.hearings);
    const hasDocketHearings = !_.isEmpty(docketHearings);
    const hasPrevHearings = !_.isEmpty(prevHearings);

    const {
      dailyDocket, onClickRemoveHearingDay, displayRemoveHearingDayModal, displayLockModal, openModal,
      deleteHearingDay, updateLockHearingDay, onCancelDisplayLockModal, user
    } = this.props;

    const { editedDispositionModalProps } = this.state;

    return <AppSegment filledBackground>

      {editedDispositionModalProps &&
        <DispositionModal
          {...this.state.editedDispositionModalProps}
          onCancel={this.closeDispositionModal} />}

      {displayRemoveHearingDayModal &&
        <RemoveHearingModal dailyDocket={dailyDocket}
          onClickRemoveHearingDay={onClickRemoveHearingDay}
          deleteHearingDay={deleteHearingDay} />}

      {displayLockModal &&
        <LockModal
          dailyDocket={dailyDocket}
          updateLockHearingDay={updateLockHearingDay}
          onCancelDisplayLockModal={onCancelDisplayLockModal} />}

      <Alerts
        dailyDocket={dailyDocket}
        user={user}
        saveSuccessful={this.props.saveSuccessful}
        displayLockSuccessMessage={this.props.displayLockSuccessMessage}
        dailyDocketServerError={this.props.dailyDocketServerError}
        onErrorHearingDayLock={this.props.onErrorHearingDayLock} />

      <div className="cf-app-segment">
        <div className="cf-push-left">
          <DailyDocketEditLinks
            dailyDocket={dailyDocket}
            user={user}
            openModal={openModal}
            onDisplayLockModal={this.props.onDisplayLockModal}
            hasHearings={hasHearings}
            onClickRemoveHearingDay={this.props.onClickRemoveHearingDay} />
        </div>
        <div className="cf-push-right">
          VLJ: {dailyDocket.judgeFirstName} {dailyDocket.judgeLastName} <br />
          Coordinator: {dailyDocket.bvaPoc} <br />
          Hearing type: {dailyDocket.requestType} <br />
          Regional office: {dailyDocket.regionalOffice}<br />
          Room number: {dailyDocket.room}
        </div>
      </div>

      {hasDocketHearings &&
        <DailyDocketRows
          hearings={this.dailyDocketHearings()}
          readOnly={user.userRoleView || user.userRoleVso}
          saveHearing={this.saveHearing}
          openDispositionModal={this.openDispositionModal}
          regionalOffice={regionalOffice}
          user={user} />}

      {!hasDocketHearings &&
        <div {...css({ marginTop: '75px' })}>
          <StatusMessage
            title= "No Veterans are scheduled for this hearing day."
            type="status" />
        </div>}

      {hasPrevHearings &&
        <div {...css({ marginTop: '75px' })}>
          <h1>Previously Scheduled</h1>
          <DailyDocketRows
            hearings={prevHearings}
            regionalOffice={regionalOffice}
            user={user}
            readOnly />
        </div>}
    </AppSegment>;
  }
}

DailyDocket.propTypes = {
  dailyDocket: PropTypes.object,
  hearings: PropTypes.object,
  onHearingNotesUpdate: PropTypes.func,
  onHearingDispositionUpdate: PropTypes.func,
  onHearingTimeUpdate: PropTypes.func,
  onHearingRegionalOfficeUpdate: PropTypes.func,
  onInvalidForm: PropTypes.func,
  openModal: PropTypes.func,
  deleteHearingDay: PropTypes.func,
  notes: PropTypes.string
};
