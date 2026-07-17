class CreateScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.boolean :private, null: false, default: false
      t.datetime :scheduled_at, null: false
      t.integer :status, null: false, default: 0
      t.bigint :message_id
      t.timestamps
    end

    add_index :scheduled_messages, [:conversation_id, :status]
    add_index :scheduled_messages, [:status, :scheduled_at]
  end
end
