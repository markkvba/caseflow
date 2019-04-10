import moment from 'moment';
import { css } from 'glamor';
import _ from 'lodash';

import LEGACY_APPEAL_TYPES_BY_ID from '../../../constants/LEGACY_APPEAL_TYPES_BY_ID.json';

export const docketCutoffLineStyle = (_index, text) => {
  const isEmpty = _index < 0;
  const index = isEmpty ? 0 : _index;

  const style = {
    [`& #table-row-${index + 1} td`]: {
      paddingTop: '35px'
    },
    [`& #table-row-${index}`]: {
      borderBottom: '2px solid #000',
      position: 'relative',
      '& td': {
        paddingBottom: '35px'
      },
      '& td:first-child::before': {
        content: text || `Schedule for ${moment(new Date()).format('MMMM YYYY')}`,
        display: 'block',
        position: 'absolute',
        transform: `translateY(calc(100% ${text ? '-' : '+'} 4px))`,
        background: '#fff',
        padding: '10px 10px 10px 0px',
        height: '42px',
        fontWeight: 'bold'
      }
    }
  };

  const isEmptyStyle = isEmpty ? {
    '& th': {
      paddingBottom: '35px'
    },
    [`& #table-row-${index}`]: {
      borderTop: '2px solid #000',
      borderBottom: 0,
      '& td': {
        paddingTop: '35px',
        paddingBottom: '15px'
      },
      '& td:first-child::before': {
        transform: 'translateY(-140%)',
        content: 'All veterans have been scheduled for this hearing docket date.'
      }
    }
  } : {};

  return css(_.merge(style, isEmptyStyle));
};

export const getIndexOfDocketLine = (allAppeals, appealsInDocketRange) => {
  const numberOfAppealsInDocketRange = appealsInDocketRange.length;
  const numberOfAodAndCavcAppeals = _.filter(allAppeals, (appeal) => (
    appeal.attributes.caseType === LEGACY_APPEAL_TYPES_BY_ID.cavc_remand ||
    appeal.attributes.aod
  )).length;

  const appealsThisDocket = numberOfAppealsInDocketRange + numberOfAodAndCavcAppeals;

  return appealsThisDocket - 1;
};
