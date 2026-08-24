import types from '../mutation-types';
import ConversationAPI from '../../api/inbox/conversation';

export const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
  },
};

export const getters = {
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getScheduledMessagesByConversation: _state => conversationId => {
    return _state.records[conversationId] || [];
  },
};

export const actions = {
  async get({ commit }, { conversationId }) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: true });
    try {
      const { data } =
        await ConversationAPI.getScheduledMessages(conversationId);
      commit(types.SET_SCHEDULED_MESSAGES, { conversationId, data });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: false });
    }
  },

  async create(
    { commit },
    {
      conversationId,
      content,
      private: isPrivate,
      scheduledAt,
      templateParams,
      mediaAssetIds,
    }
  ) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: true });
    try {
      const { data } = await ConversationAPI.createScheduledMessage(
        conversationId,
        {
          content,
          private: isPrivate,
          scheduled_at: scheduledAt,
          template_params: templateParams || {},
          media_asset_ids: mediaAssetIds || [],
        }
      );
      commit(types.ADD_SCHEDULED_MESSAGE, { conversationId, data });
      return data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: false });
    }
  },

  async delete({ commit }, { conversationId, id }) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: true });
    try {
      await ConversationAPI.deleteScheduledMessage(conversationId, id);
      commit(types.DELETE_SCHEDULED_MESSAGE, { conversationId, id });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_SCHEDULED_MESSAGES_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_SCHEDULED_MESSAGES]($state, { data, conversationId }) {
    $state.records = {
      ...$state.records,
      [conversationId]: data,
    };
  },

  [types.ADD_SCHEDULED_MESSAGE]($state, { data, conversationId }) {
    const records = $state.records[conversationId] || [];
    $state.records = {
      ...$state.records,
      [conversationId]: [...records, data].sort(
        (a, b) => a.scheduled_at - b.scheduled_at
      ),
    };
  },

  [types.DELETE_SCHEDULED_MESSAGE]($state, { conversationId, id }) {
    const records = $state.records[conversationId] || [];
    $state.records = {
      ...$state.records,
      [conversationId]: records.filter(record => record.id !== id),
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
