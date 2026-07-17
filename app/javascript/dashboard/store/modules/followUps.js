import types from '../mutation-types';
import FollowUpRunsAPI from '../../api/followUpRuns';
import FollowUpWorkflowsAPI from '../../api/followUpWorkflows';

export const state = {
  recordsByConversation: {},
  dueRecords: [],
  historyRecords: [],
  workflows: [],
  analytics: null,
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isFetchingWorkflows: false,
    isSavingWorkflow: false,
    isFetchingAnalytics: false,
    isFetchingHistory: false,
    isRetrying: false,
  },
};

export const getters = {
  getUIFlags: $state => $state.uiFlags,
  getFollowUpsByConversation: $state => conversationId =>
    $state.recordsByConversation[conversationId] || [],
  getDueFollowUps: $state => $state.dueRecords,
  getHistoryFollowUps: $state => $state.historyRecords,
  getWorkflows: $state => $state.workflows,
  getAnalytics: $state => $state.analytics,
};

export const actions = {
  async getForConversation({ commit }, { conversationId }) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await FollowUpRunsAPI.getForConversation(conversationId);
      commit(types.SET_CONVERSATION_FOLLOW_UPS, { conversationId, data });
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetching: false });
    }
  },

  async create({ commit }, { conversationId, payload }) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isCreating: true });
    try {
      const { data } = await FollowUpRunsAPI.createForConversation(
        conversationId,
        payload
      );
      commit(types.ADD_CONVERSATION_FOLLOW_UP, { conversationId, data });
      return data;
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isCreating: false });
    }
  },

  async cancel({ commit }, { conversationId, id }) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isDeleting: true });
    try {
      await FollowUpRunsAPI.cancel(conversationId, id);
      commit(types.DELETE_CONVERSATION_FOLLOW_UP, { conversationId, id });
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isDeleting: false });
    }
  },

  async retry({ commit }, { id, conversationId }) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isRetrying: true });
    try {
      const { data } = conversationId
        ? await FollowUpRunsAPI.retryForConversation(conversationId, id)
        : await FollowUpRunsAPI.retry(id);

      commit(types.UPDATE_FOLLOW_UP_HISTORY_ITEM, data);
      if (conversationId) {
        commit(types.UPDATE_CONVERSATION_FOLLOW_UP, {
          conversationId,
          data,
        });
      }
      return data;
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isRetrying: false });
    }
  },

  async getDue({ commit }, params = {}) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetching: true });
    try {
      const { data } = await FollowUpRunsAPI.getDue(params);
      commit(types.SET_DUE_FOLLOW_UPS, data);
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetching: false });
    }
  },

  async getHistory({ commit }, params = {}) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetchingHistory: true });
    try {
      const { data } = await FollowUpRunsAPI.getHistory(params);
      commit(types.SET_FOLLOW_UP_HISTORY, data);
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetchingHistory: false });
    }
  },

  async getWorkflows({ commit }) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetchingWorkflows: true });
    try {
      const { data } = await FollowUpWorkflowsAPI.get();
      commit(types.SET_FOLLOW_UP_WORKFLOWS, data);
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetchingWorkflows: false });
    }
  },

  async createWorkflow({ commit }, payload) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isSavingWorkflow: true });
    try {
      const { data } = await FollowUpWorkflowsAPI.create({
        follow_up_workflow: payload,
      });
      commit(types.ADD_FOLLOW_UP_WORKFLOW, data);
      return data;
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isSavingWorkflow: false });
    }
  },

  async updateWorkflow({ commit }, { id, ...payload }) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isSavingWorkflow: true });
    try {
      const { data } = await FollowUpWorkflowsAPI.update(id, {
        follow_up_workflow: payload,
      });
      commit(types.EDIT_FOLLOW_UP_WORKFLOW, data);
      return data;
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isSavingWorkflow: false });
    }
  },

  async deleteWorkflow({ commit }, id) {
    await FollowUpWorkflowsAPI.delete(id);
    commit(types.DELETE_FOLLOW_UP_WORKFLOW, id);
  },

  async getAnalytics({ commit }) {
    commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetchingAnalytics: true });
    try {
      const { data } = await FollowUpWorkflowsAPI.getAnalytics();
      commit(types.SET_FOLLOW_UP_ANALYTICS, data.analytics || data);
    } finally {
      commit(types.SET_FOLLOW_UPS_UI_FLAG, { isFetchingAnalytics: false });
    }
  },
};

export const mutations = {
  [types.SET_FOLLOW_UPS_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [types.SET_CONVERSATION_FOLLOW_UPS]($state, { conversationId, data }) {
    $state.recordsByConversation = {
      ...$state.recordsByConversation,
      [conversationId]: data,
    };
  },
  [types.ADD_CONVERSATION_FOLLOW_UP]($state, { conversationId, data }) {
    const current = $state.recordsByConversation[conversationId] || [];
    $state.recordsByConversation = {
      ...$state.recordsByConversation,
      [conversationId]: [data, ...current],
    };
  },
  [types.DELETE_CONVERSATION_FOLLOW_UP]($state, { conversationId, id }) {
    const current = $state.recordsByConversation[conversationId] || [];
    $state.recordsByConversation = {
      ...$state.recordsByConversation,
      [conversationId]: current.filter(item => item.id !== id),
    };
  },
  [types.UPDATE_CONVERSATION_FOLLOW_UP]($state, { conversationId, data }) {
    const current = $state.recordsByConversation[conversationId] || [];
    $state.recordsByConversation = {
      ...$state.recordsByConversation,
      [conversationId]: current.map(item =>
        item.id === data.id ? data : item
      ),
    };
  },
  [types.SET_DUE_FOLLOW_UPS]($state, data) {
    $state.dueRecords = data;
  },
  [types.SET_FOLLOW_UP_HISTORY]($state, data) {
    $state.historyRecords = data;
  },
  [types.UPDATE_FOLLOW_UP_HISTORY_ITEM]($state, data) {
    $state.historyRecords = $state.historyRecords.map(item =>
      item.id === data.id ? data : item
    );
  },
  [types.SET_FOLLOW_UP_WORKFLOWS]($state, data) {
    $state.workflows = data;
  },
  [types.ADD_FOLLOW_UP_WORKFLOW]($state, data) {
    $state.workflows = [...$state.workflows, data];
  },
  [types.EDIT_FOLLOW_UP_WORKFLOW]($state, data) {
    $state.workflows = $state.workflows.map(item =>
      item.id === data.id ? data : item
    );
  },
  [types.DELETE_FOLLOW_UP_WORKFLOW]($state, id) {
    $state.workflows = $state.workflows.filter(item => item.id !== id);
  },
  [types.SET_FOLLOW_UP_ANALYTICS]($state, data) {
    $state.analytics = data;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
