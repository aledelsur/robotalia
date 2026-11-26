class CreateAccountImports < ActiveRecord::Migration[8.1]
  def change
    create_table :account_imports do |t|
      # Empty until the job has read the account from the report header.
      t.references :account, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.integer :new_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.jsonb :error_messages, null: false, default: []
      t.datetime :finished_at

      t.timestamps
    end
  end
end
