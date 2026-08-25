require 'rails_helper'

RSpec.describe 'Whatsapp Template Categories API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/whatsapp_template_categories" }

  describe 'GET index' do
    it 'exige autenticacao' do
      get base

      expect(response).to have_http_status(:unauthorized)
    end

    it 'devolve as categorias da conta' do
      account.whatsapp_template_categories.create!(name: 'Vendas', color: '#22c55e')

      get base, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.first['name']).to eq('Vendas')
      expect(payload.first['color']).to eq('#22c55e')
    end

    it 'nao vaza categoria de outra conta' do
      create(:account).whatsapp_template_categories.create!(name: 'De outra conta')

      get base, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload']).to be_empty
    end
  end

  describe 'POST create' do
    it 'cria para administrador' do
      post base, params: { whatsapp_template_category: { name: 'Cobranca' } },
                 headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(account.whatsapp_template_categories.pluck(:name)).to eq(['Cobranca'])
    end

    it 'recusa para agente' do
      post base, params: { whatsapp_template_category: { name: 'Cobranca' } },
                 headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
      expect(account.whatsapp_template_categories).to be_empty
    end
  end

  describe 'POST assign' do
    let(:vendas) { account.whatsapp_template_categories.create!(name: 'Vendas') }
    let(:cobranca) { account.whatsapp_template_categories.create!(name: 'Cobranca') }

    it 'atribui e devolve a categoria' do
      post "#{base}/#{vendas.id}/assign", params: { template_names: ['locfit_boas_vindas'] },
                                          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['template_names']).to eq(['locfit_boas_vindas'])
    end

    it 'move o template entre categorias' do
      vendas.assign_templates!(['locfit_boas_vindas'])

      post "#{base}/#{cobranca.id}/assign", params: { template_names: ['locfit_boas_vindas'] },
                                            headers: admin.create_new_auth_token

      expect(vendas.reload.template_names).to be_empty
      expect(cobranca.reload.template_names).to eq(['locfit_boas_vindas'])
    end

    it 'recusa para agente' do
      post "#{base}/#{vendas.id}/assign", params: { template_names: ['locfit_boas_vindas'] },
                                          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE destroy' do
    it 'apaga a categoria e as atribuicoes' do
      vendas = account.whatsapp_template_categories.create!(name: 'Vendas')
      vendas.assign_templates!(['locfit_boas_vindas'])

      delete "#{base}/#{vendas.id}", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(account.whatsapp_template_categories.reload).to be_empty
      expect(account.whatsapp_template_category_items.reload).to be_empty
    end
  end
end
