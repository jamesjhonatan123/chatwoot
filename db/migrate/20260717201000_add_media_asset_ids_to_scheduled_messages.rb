class AddMediaAssetIdsToScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :scheduled_messages, :media_asset_ids, :jsonb, null: false, default: []
    change_column_null :scheduled_messages, :content, true
  end
end
