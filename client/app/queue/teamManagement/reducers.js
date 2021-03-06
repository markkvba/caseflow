import { ACTIONS } from './constants';
import { update } from '../../util/ReducerUtil';

export const initialState = {
  judgeTeams: [],
  vsos: [],
  otherOrgs: []
};

const teamManagementReducer = (state = initialState, action = {}) => {
  switch (action.type) {
  case ACTIONS.ON_RECEIVE_TEAM_LIST:
    return update(state, {
      judgeTeams: { $set: action.payload.judge_teams },
      vsos: { $set: action.payload.vsos },
      otherOrgs: { $set: action.payload.other_orgs }
    });
  case ACTIONS.ON_RECEIVE_NEW_JUDGE_TEAM:
    return update(state, {
      judgeTeams: { $set: state.judgeTeams.concat(action.payload.org) }
    });
  case ACTIONS.ON_RECEIVE_NEW_VSO:
    return update(state, {
      vsos: { $set: state.vsos.concat(action.payload.org) }
    });
  default:
    return state;
  }
};

export default teamManagementReducer;
