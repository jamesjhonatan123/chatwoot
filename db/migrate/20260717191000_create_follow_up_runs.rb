class CreateFollowUpRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :follow_up_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :follow_up_workflow, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :run_type, null: false, default: 'workflow'
      t.datetime :anchor_at, null: false
      t.datetime :next_due_at
      t.integer :current_step_index, null: false, default: 0
      t.jsonb :context, null: false, default: {}
      t.boolean :cancel_on_incoming, null: false, default: true
      t.timestamps
    end

    add_index :follow_up_runs, [:conversation_id, :status]
    add_index :follow_up_runs, [:account_id, :status, :next_due_at]
    add_index :follow_up_runs, [:status, :next_due_at]
  end
end
