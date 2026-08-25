# Categoria propria para organizar os templates de WhatsApp — "Vendas",
# "Cobranca", "Logistica". Nao tem relacao com o `category` da Meta
# (UTILITY/MARKETING/AUTHENTICATION), que so aceita aqueles tres valores.
# == Schema Information
#
# Table name: whatsapp_template_categories
#
#  id         :bigint           not null, primary key
#  color      :string           default("#1f93ff"), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_whatsapp_template_categories_on_account_id           (account_id)
#  index_whatsapp_template_categories_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class WhatsappTemplateCategory < ApplicationRecord
  belongs_to :account
  has_many :items, class_name: 'WhatsappTemplateCategoryItem',
                   foreign_key: :whatsapp_template_category_id,
                   dependent: :destroy,
                   inverse_of: :category

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :color, format: { with: /\A#(?:\h{3}|\h{6})\z/, message: I18n.t('errors.validations.invalid_color', default: 'deve ser uma cor hexadecimal') }

  default_scope { order(:name) }

  def template_names
    items.pluck(:template_name)
  end

  # Um template pertence a uma categoria de cada vez: atribuir a esta remove
  # a atribuicao anterior, seja ela qual for.
  def assign_templates!(names)
    Array(names).map(&:to_s).map(&:strip).reject(&:blank?).uniq.each do |name|
      item = account.whatsapp_template_category_items.find_or_initialize_by(template_name: name)
      item.category = self
      item.save!
    end
  end

  def unassign_templates!(names)
    items.where(template_name: Array(names).map(&:to_s)).destroy_all
  end
end
