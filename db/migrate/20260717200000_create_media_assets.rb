class CreateMediaAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :media_assets do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.integer :file_type, null: false, default: 0
      t.string :file_name, null: false, default: ''
      t.string :title
      t.text :description
      t.bigint :byte_size, null: false, default: 0
      t.string :content_type, null: false, default: ''

      t.timestamps
    end

    add_index :media_assets, [:account_id, :file_type]
    add_index :media_assets, [:account_id, :created_at]
  end
end
