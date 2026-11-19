/* global axios */
import ApiClient from './ApiClient';

// Painel da LIA (lia_panels_controller.rb).
class LiaPanelAPI extends ApiClient {
  constructor() {
    super('lia_panel', { accountScoped: true });
  }

  get({ period, storeId } = {}) {
    return axios.get(this.url, {
      params: { period, store_id: storeId || undefined },
    });
  }
}

export default new LiaPanelAPI();
