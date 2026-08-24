/* global axios */
import ApiClient from './ApiClient';

class MediaAssetsAPI extends ApiClient {
  constructor() {
    super('media_assets', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  create(formData) {
    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new MediaAssetsAPI();
