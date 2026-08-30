class AddSkipAgentSignatureToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :skip_agent_signature, :boolean, default: false, null: false
  end
end
