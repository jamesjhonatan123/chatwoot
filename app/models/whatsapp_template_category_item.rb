# Liga um template (pelo nome, que e o que sobrevive ao sync com a Meta) a uma
# categoria. Escopo de conta: o mesmo nome de template pode existir em varias
# caixas e idiomas, e a organizacao vale para todos.
# == Schema Information
#
# Table name: whatsapp_template_category_items
#
#  id                            :bigint           not null, primary key
#  template_name                 :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#  whatsapp_template_category_id :bigint           not null
#
# Indexes
#
#  index_wa_template_items_on_account_and_name           (account_id,template_name) UNIQUE
#  index_wa_template_items_on_category                   (whatsapp_template_category_id)
#  index_whatsapp_template_category_items_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (whatsapp_template_category_id => whatsapp_template_categories.id)
#
class WhatsappTemplateCategoryItem < ApplicationRecord
  belongs_to :account
  belongs_to :category, class_name: 'WhatsappTemplateCategory',
                        foreign_key: :whatsapp_template_category_id,
                        inverse_of: :items

  validates :template_name, presence: true,
                            uniqueness: { scope: :account_id }

  before_validation :inherit_account

  private

  def inherit_account
    self.account ||= category&.account
  end
end
