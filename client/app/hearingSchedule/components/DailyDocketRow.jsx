import React from 'react';
import _ from 'lodash';
import { css } from 'glamor';
import moment from 'moment';
import { connect } from 'react-redux';
import { bindActionCreators } from 'redux';

import { getTimeWithoutTimeZone } from '../../util/DateUtil';

import Link from '@department-of-veterans-affairs/caseflow-frontend-toolkit/components/Link';
import Button from '../../components/Button';
import SearchableDropdown from '../../components/SearchableDropdown';
import Checkbox from '../../components/Checkbox';
import TextareaField from '../../components/TextareaField';
import { AppealHearingLocationsDropdown } from '../../components/DataDropdowns';
import HearingTime from './modalForms/HearingTime';
import { pencilSymbol } from '../../components/RenderFunctions';

import { DISPOSITION_OPTIONS } from '../../hearings/constants/constants';
import { onUpdateDocketHearing } from '../actions';
import HearingText from './DailyDocketRowDisplayText';

const staticSpacing = css({ marginTop: '5px' });

const DispositionDropdown = ({
  hearing, update, readOnly, cancelUpdate, openDispositionModal, saveHearing
}) => {

  return <div><SearchableDropdown
    name="Disposition"
    strongLabel
    options={DISPOSITION_OPTIONS}
    value={hearing.disposition}
    onChange={(option) => {
      openDispositionModal({
        hearing,
        disposition: option.value,
        onConfirm: () => {
          if (option.value === 'postponed') {
            cancelUpdate();
          }

          update({ disposition: option.value });
          saveHearing();
        }
      });
    }}
    readOnly={readOnly || !hearing.dispositionEditable}
  /></div>;
};

const Waive90DayHoldCheckbox = ({ hearing, readOnly, update }) => (
  <div>
    <b>Waive 90 Day Evidence Hold</b>
    <Checkbox
      label="Yes, Waive 90 Day Hold"
      name={`${hearing.id}.evidenceWindowWaived`}
      value={hearing.evidenceWindowWaived || false}
      onChange={(evidenceWindowWaived) => update({ evidenceWindowWaived })}
      disabled={readOnly} />
  </div>
);

const TranscriptRequestedCheckbox = ({ hearing, readOnly, update }) => (
  <div>
    <b>Copy Requested by Appellant/Rep</b>
    <Checkbox
      label="Transcript Requested"
      name={`${hearing.id}.transcriptRequested`}
      value={hearing.transcriptRequested || false}
      onChange={(transcriptRequested) => update({ transcriptRequested })}
      disabled={readOnly} />
  </div>
);

const HearingDetailsLink = ({ hearing }) => (
  <div>
    <b>Hearing Details</b><br />
    <div {...staticSpacing}>
      <Link href={`/hearings/${hearing.externalId}/details`}>
        Edit Hearing Details
        <span {...css({ position: 'absolute' })}>
          {pencilSymbol()}
        </span>
      </Link>
    </div>
  </div>
);

const AodDropdown = ({ hearing, readOnly, update }) => {
  return <SearchableDropdown
    label="AOD"
    readOnly={true || readOnly}
    name={`${hearing.id}-aodReason`}
    options={[{ value: 'granted',
      label: 'Granted' },
    { value: 'filed',
      label: 'Filed' },
    { value: 'none',
      label: 'None' }]}
    onChange={(aod) => update({ aod })}
    value={hearing.aod}
    searchable={false}
  />;
};

const AodReasonDropdown = ({ hearing, readOnly, update }) => {
  return <SearchableDropdown
    label="AOD Reason"
    readOnly={true || readOnly}
    name={`${hearing.id}-aod`}
    options={[]}
    onChange={(aodReason) => update({ aodReason })}
    value={hearing.aodReason}
    searchable={false}
  />;
};

const HearingPrepWorkSheetLink = ({ hearing }) => (
  <div>
    <b>Hearing Prep Worksheet</b><br />
    <div {...staticSpacing}>
      <Link href={`/hearings/${hearing.externalId}/worksheet`}>
        Edit VLJ Hearing Worksheet
        <span {...css({ position: 'absolute' })}>
          {pencilSymbol()}
        </span>
      </Link>
    </div>
  </div>
);

const StaticRegionalOffice = ({ hearing }) => (
  <div>
    <b>Regional Office</b><br />
    <div {...staticSpacing}>
      {hearing.readableRequestType === 'Central' ? hearing.readableRequestType : hearing.regionalOfficeName}<br />
    </div>
  </div>
);

const NotesField = ({ hearing, update, readOnly }) => (
  <TextareaField
    name="Notes"
    strongLabel
    disabled={readOnly}
    onChange={(notes) => update({ notes })}
    textAreaStyling={css({ height: '50px' })}
    value={hearing.notes || ''}
  />
);

const HearingLocationDropdown = ({ hearing, readOnly, regionalOffice, update }) => {
  const roIsDifferent = regionalOffice !== hearing.closestRegionalOffice;
  let staticHearingLocations = _.isEmpty(hearing.availableHearingLocations) ?
    [hearing.location] : _.values(hearing.availableHearingLocations);

  if (roIsDifferent) {
    staticHearingLocations = null;
  }

  return <AppealHearingLocationsDropdown
    readOnly={readOnly}
    appealId={hearing.appealExternalId}
    regionalOffice={regionalOffice}
    staticHearingLocations={staticHearingLocations}
    dynamic={_.isEmpty(hearing.availableHearingLocations) || roIsDifferent}
    value={hearing.location ? hearing.location.facilityId : null}
    onChange={(location) => update({ location })}
  />;
};

const StaticHearingDay = ({ hearing }) => (
  <div>
    <b>Hearing Day</b><br />
    <div {...staticSpacing}>{moment(hearing.scheduledFor).format('ddd M/DD/YYYY')} <br /> <br /></div>
  </div>
);

const TimeRadioButtons = ({ hearing, regionalOffice, update, readOnly }) => {
  const timezone = hearing.readableRequestType === 'Central' ? 'America/New_York' : hearing.regionalOfficeTimezone;

  const value = hearing.editedTime ? hearing.editedTime : getTimeWithoutTimeZone(hearing.scheduledFor, timezone);

  return <HearingTime
    regionalOffice={regionalOffice}
    value={value}
    readOnly={readOnly}
    onChange={(editedTime) => update({ editedTime })} />;
};

const SaveButton = ({ hearing, cancelUpdate, saveHearing }) => {
  return <div {...css({
    content: ' ',
    clear: 'both',
    display: 'block'
  })}>
    <Button
      styling={css({ float: 'left' })}
      linkStyling
      onClick={cancelUpdate}>
      Cancel
    </Button>
    <Button
      styling={css({ float: 'right' })}
      disabled={hearing.dateEdited && !hearing.dispositionEdited}
      onClick={saveHearing}>
      Save
    </Button>
  </div>;
};

const inputSpacing = css({
  '& > div:not(:first-child)': {
    marginTop: '25px'
  }
});

class HearingActions extends React.Component {
  constructor (props) {
    super(props);

    this.state = {
      initialState: {
        ...props.hearing,
        editedTime: null
      },
      edited: false
    };
  }

  update = (values) => {
    this.props.update(values);
    this.setState({ edited: true });
  }

  cancelUpdate = () => {
    this.props.update(this.state.initialState);
    this.setState({ edited: false });
  }

  saveHearing = () => {
    this.props.saveHearing(this.props.hearingId);
    setTimeout(() => {
      this.setState({
        initialState: { ...this.props.hearing },
        edited: false
      });
    }, 0);
  }

  defaultRightColumn = () => {
    const { hearing, regionalOffice, readOnly } = this.props;

    const inputProps = {
      hearing,
      readOnly,
      update: this.update
    };

    return <div {...inputSpacing}>
      <StaticRegionalOffice hearing={hearing} />
      <HearingLocationDropdown {...inputProps} regionalOffice={regionalOffice} />
      <StaticHearingDay hearing={hearing} />
      <TimeRadioButtons {...inputProps} regionalOffice={regionalOffice} />
      {this.state.edited &&
        <SaveButton
          hearing={hearing}
          cancelUpdate={this.cancelUpdate}
          saveHearing={this.saveHearing} />
      }
    </div>;
  }

  judgeRightColumn = () => {
    const { hearing, readOnly } = this.props;

    const inputProps = {
      hearing,
      readOnly,
      update: this.update
    };

    return <div {...inputSpacing}>
      <HearingPrepWorkSheetLink hearing={hearing} />
      <AodDropdown {...inputProps} />
      <AodReasonDropdown {...inputProps} />
      {this.state.edited &&
        <SaveButton
          hearing={hearing}
          cancelUpdate={this.cancelUpdate}
          saveHearing={this.saveHearing} />
      }
    </div>;
  }

  getRightColumn = () => {
    const { user } = this.props;

    if (user.userInJudgeTeam) {
      return this.judgeRightColumn();
    }

    return this.defaultRightColumn();
  }

  getLeftColumn = () => {
    const { hearing, user, readOnly, openDispositionModal } = this.props;

    const inputProps = {
      hearing,
      readOnly,
      update: this.update
    };

    return <div {...inputSpacing}>
      <DispositionDropdown {...inputProps}
        cancelUpdate={this.cancelUpdate}
        saveHearing={this.saveHearing}
        openDispositionModal={openDispositionModal} />
      {(user.userInJudgeTeam && hearing.docketName === 'hearing') &&
        <Waive90DayHoldCheckbox {...inputProps} />}
      <TranscriptRequestedCheckbox {...inputProps} />
      {(user.userRoleAssign && !user.userInJudgeTeam) && <HearingDetailsLink hearing={hearing} />}
      <NotesField {...inputProps} readOnly={user.userRoleVso} />
    </div>;
  }

  render () {
    const { hearing, user, index, readOnly } = this.props;

    return <React.Fragment>
      <div>
        <HearingText
          readOnly={readOnly}
          update={this.update}
          hearing={hearing}
          user={user}
          index={index} />
      </div><div>
        {this.getLeftColumn()}
        {this.getRightColumn()}
      </div>
    </React.Fragment>;
  }
}

const mapStateToProps = (state, props) => ({
  hearing: props.hearingId ? state.hearingSchedule.hearings[props.hearingId] : {}
});

const mapDispatchToProps = (dispatch, props) => bindActionCreators({
  update: (values) => onUpdateDocketHearing(props.hearingId, values)
}, dispatch);

export default connect(mapStateToProps, mapDispatchToProps)(HearingActions);
