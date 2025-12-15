import ApiClient from './ApiClient';

class KanbanAPI extends ApiClient {
  constructor() {
    super('kanban', { accountScoped: true });
  }

  get(params) {
    return axios.get(this.url, { params });
  }
}

export default new KanbanAPI();
