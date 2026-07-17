/* global axios */
import ApiClient from './ApiClient';

class FollowUpRunsAPI extends ApiClient {
  constructor() {
    super('follow_up_runs', { accountScoped: true });
  }

  getDue(params = {}) {
    return axios.get(this.url, { params });
  }

  getHistory(params = {}) {
    return axios.get(this.url, {
      params: {
        history: true,
        ...params,
      },
    });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  retry(id) {
    return axios.post(`${this.url}/${id}/retry`);
  }

  getForConversation(conversationId) {
    return axios.get(
      `${this.baseUrl()}/conversations/${conversationId}/follow_up_runs`
    );
  }

  createForConversation(conversationId, payload) {
    return axios.post(
      `${this.baseUrl()}/conversations/${conversationId}/follow_up_runs`,
      { follow_up_run: payload }
    );
  }

  cancel(conversationId, id) {
    return axios.delete(
      `${this.baseUrl()}/conversations/${conversationId}/follow_up_runs/${id}`
    );
  }

  retryForConversation(conversationId, id) {
    return axios.post(
      `${this.baseUrl()}/conversations/${conversationId}/follow_up_runs/${id}/retry`
    );
  }
}

export default new FollowUpRunsAPI();
