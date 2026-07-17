class CreateFollowUpWorkflows < ActiveRecord::Migration[7.1]
  def change
    create_table :follow_up_workflows do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :trigger_mode, null: false, default: 'manual'
      t.jsonb :steps, null: false, default: []
      t.boolean :active, null: false, default: true
      t.boolean :system_preset, null: false, default: false
      t.string :preset_key
      t.timestamps
    end

    add_index :follow_up_workflows, [:account_id, :preset_key], unique: true, where: 'preset_key IS NOT NULL'
    add_index :follow_up_workflows, [:account_id, :active]
  end
end
