require 'rails_helper'

RSpec.describe WhatsappTemplateCategory do
  let(:account) { create(:account) }

  it 'nao aceita duas categorias com o mesmo nome na conta, ignorando caixa' do
    account.whatsapp_template_categories.create!(name: 'Vendas')
    duplicada = account.whatsapp_template_categories.build(name: 'vendas')

    expect(duplicada).not_to be_valid
    expect(duplicada.errors[:name]).to be_present
  end

  it 'aceita o mesmo nome em contas diferentes' do
    account.whatsapp_template_categories.create!(name: 'Vendas')
    outra = create(:account).whatsapp_template_categories.build(name: 'Vendas')

    expect(outra).to be_valid
  end

  it 'exige cor hexadecimal' do
    categoria = account.whatsapp_template_categories.build(name: 'Vendas', color: 'azul')

    expect(categoria).not_to be_valid
    expect(categoria.errors[:color]).to be_present
  end

  describe '#assign_templates!' do
    let(:vendas) { account.whatsapp_template_categories.create!(name: 'Vendas') }
    let(:cobranca) { account.whatsapp_template_categories.create!(name: 'Cobranca') }

    it 'atribui pelo nome do template' do
      vendas.assign_templates!(%w[locfit_boas_vindas locfit_promo])

      expect(vendas.reload.template_names).to contain_exactly('locfit_boas_vindas', 'locfit_promo')
    end

    it 'ignora repetidos e espacos em branco' do
      vendas.assign_templates!(['  locfit_boas_vindas  ', 'locfit_boas_vindas', '', nil])

      expect(vendas.reload.template_names).to eq(['locfit_boas_vindas'])
    end

    # Um template pertence a uma categoria de cada vez: e o que faz o filtro
    # somar 100% e nao mostrar o mesmo template em dois lugares.
    it 'move o template, tirando-o da categoria anterior' do
      vendas.assign_templates!(['locfit_boas_vindas'])
      cobranca.assign_templates!(['locfit_boas_vindas'])

      expect(vendas.reload.template_names).to be_empty
      expect(cobranca.reload.template_names).to eq(['locfit_boas_vindas'])
    end

    it 'remove a atribuicao' do
      vendas.assign_templates!(['locfit_boas_vindas'])
      vendas.unassign_templates!(['locfit_boas_vindas'])

      expect(vendas.reload.template_names).to be_empty
    end

    it 'leva os itens junto quando a categoria e apagada' do
      vendas.assign_templates!(['locfit_boas_vindas'])

      expect { vendas.destroy! }.to change(WhatsappTemplateCategoryItem, :count).by(-1)
    end
  end
end
