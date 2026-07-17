class AddSignWithAgentNameToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :sign_with_agent_name, :boolean, default: false, null: false
  end
end
