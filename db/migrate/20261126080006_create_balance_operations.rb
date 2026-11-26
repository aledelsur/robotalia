class CreateBalanceOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :balance_operations do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.bigint :ticket, null: false
      t.datetime :executed_at, null: false
      t.string :kind, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :comment

      t.timestamps
    end
    add_index :balance_operations, %i[account_id ticket], unique: true
  end
end
