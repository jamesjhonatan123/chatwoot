import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import MediaAssetsAPI from '../../api/mediaAssets';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isDeleting: false,
    isUpdating: false,
  },
};

export const getters = {
  getMediaAssets($state) {
    return $state.records;
  },
  getMediaAsset: $state => id => {
    return $state.records.find(record => record.id === Number(id));
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }, params = {}) => {
    commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isFetching: true });
    try {
      const response = await MediaAssetsAPI.get(params);
      commit(types.SET_MEDIA_ASSETS, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ commit }, { file, title } = {}) => {
    commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isCreating: true });
    try {
      const formData = new FormData();
      formData.append('file', file);
      if (title) formData.append('title', title);
      const response = await MediaAssetsAPI.create(formData);
      commit(types.ADD_MEDIA_ASSET, response.data.payload);
      return response.data.payload;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...updateObj }) => {
    commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isUpdating: true });
    try {
      const response = await MediaAssetsAPI.update(id, {
        media_asset: updateObj,
      });
      commit(types.EDIT_MEDIA_ASSET, response.data.payload);
      return response.data.payload;
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isDeleting: true });
    try {
      await MediaAssetsAPI.delete(id);
      commit(types.DELETE_MEDIA_ASSET, id);
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_MEDIA_ASSETS_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_MEDIA_ASSETS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.ADD_MEDIA_ASSET]: MutationHelpers.setSingleRecord,
  [types.SET_MEDIA_ASSETS]: MutationHelpers.set,
  [types.EDIT_MEDIA_ASSET]: MutationHelpers.update,
  [types.DELETE_MEDIA_ASSET]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
