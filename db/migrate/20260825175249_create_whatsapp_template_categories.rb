class CreateWhatsappTemplateCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :whatsapp_template_categories do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :color, null: false, default: '#1f93ff'

      t.timestamps
    end

    add_index :whatsapp_template_categories, [:account_id, :name], unique: true

    # O sync com a Meta substitui message_templates inteiro (update_columns),
    # entao a categoria nao pode morar dentro do JSON do template: ela vive
    # aqui, referenciada pelo nome do template.
    create_table :whatsapp_template_category_items do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :whatsapp_template_category, null: false, foreign_key: true,
                                                index: { name: 'index_wa_template_items_on_category' }
      t.string :template_name, null: false

      t.timestamps
    end

    add_index :whatsapp_template_category_items, [:account_id, :template_name],
              unique: true, name: 'index_wa_template_items_on_account_and_name'
  end
end
