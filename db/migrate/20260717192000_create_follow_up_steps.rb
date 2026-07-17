class CreateFollowUpSteps < ActiveRecord::Migration[7.1]
  def change
    create_table :follow_up_steps do |t|
      t.references :follow_up_run, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.datetime :due_at, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :step_config, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.text :error_message
      t.timestamps
    end

    add_index :follow_up_steps, [:follow_up_run_id, :position]
    add_index :follow_up_steps, [:status, :due_at]
  end
end
