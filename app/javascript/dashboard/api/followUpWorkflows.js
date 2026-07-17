/* global axios */
import ApiClient from './ApiClient';

class FollowUpWorkflowsAPI extends ApiClient {
  constructor() {
    super('follow_up_workflows', { accountScoped: true });
  }

  getAnalytics() {
    return axios.get(`${this.url}/analytics`);
  }
}

export default new FollowUpWorkflowsAPI();
