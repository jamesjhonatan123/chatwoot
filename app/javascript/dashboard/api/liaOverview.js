/* global axios */
import ApiClient from './ApiClient';

// Faixa "LIA parada" e fila "Esperando a equipe" (lia_overviews_controller.rb).
class LiaOverviewAPI extends ApiClient {
  constructor() {
    super('lia_overview', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  toggle(storeId, liaAction) {
    return axios.post(`${this.url}/toggle`, {
      store_id: storeId,
      lia_action: liaAction,
    });
  }
}

export default new LiaOverviewAPI();
