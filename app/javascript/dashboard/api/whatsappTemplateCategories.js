/* global axios */
import ApiClient from './ApiClient';

class WhatsappTemplateCategoriesAPI extends ApiClient {
  constructor() {
    super('whatsapp_template_categories', { accountScoped: true });
  }

  assign(categoryId, templateNames) {
    return axios.post(`${this.url}/${categoryId}/assign`, {
      template_names: templateNames,
    });
  }

  unassign(categoryId, templateNames) {
    return axios.post(`${this.url}/${categoryId}/unassign`, {
      template_names: templateNames,
    });
  }
}

export default new WhatsappTemplateCategoriesAPI();
