class CreateDeals < ActiveRecord::Migration[8.1]
  def change
    create_table :deals do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.bigint :ticket, null: false
      # The MT5 report links a deal to its order only. An entry order's number is the position id.
      t.bigint :order_ticket
      t.datetime :executed_at, null: false
      t.string :symbol, null: false
      t.string :side, null: false
      t.string :direction, null: false
      t.decimal :volume, precision: 12, scale: 2, null: false
      t.decimal :price, precision: 15, scale: 5, null: false
      %i[commission fee swap profit].each do |column|
        t.decimal column, precision: 15, scale: 2, null: false, default: 0
      end
      t.decimal :balance, precision: 15, scale: 2
      t.string :comment

      t.timestamps
    end
    add_index :deals, %i[account_id ticket], unique: true
    add_index :deals, %i[account_id order_ticket]
  end
end
