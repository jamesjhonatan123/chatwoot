class AddTemplateParamsToScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :scheduled_messages, :template_params, :jsonb, default: {}, null: false
  end
end
