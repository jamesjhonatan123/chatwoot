class AddFollowUpNextDueAtToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :follow_up_next_due_at, :datetime
    add_index :conversations, :follow_up_next_due_at
  end
end
