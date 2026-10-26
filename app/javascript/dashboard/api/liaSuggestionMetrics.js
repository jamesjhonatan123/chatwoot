/* global axios */
import ApiClient from './ApiClient';

// Relatorio da sugestao pronta da LIA (so administradores).
class LiaSuggestionMetricsAPI extends ApiClient {
  constructor() {
    super('lia_suggestion_metrics', { accountScoped: true });
  }

  get(days) {
    return axios.get(this.url, { params: { days } });
  }

  release(textKey) {
    return axios.post(`${this.url}/release`, { text_key: textKey });
  }
}

export default new LiaSuggestionMetricsAPI();
