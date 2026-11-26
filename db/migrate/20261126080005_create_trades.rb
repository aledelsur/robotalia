class CreateTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :trades do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :robot, foreign_key: true
      t.bigint :position_id, null: false
      t.string :symbol, null: false
      t.string :side, null: false
      t.decimal :volume, precision: 12, scale: 2, null: false
      t.datetime :opened_at, null: false
      t.datetime :closed_at, null: false
      t.decimal :open_price, precision: 15, scale: 5, null: false
      t.decimal :close_price, precision: 15, scale: 5, null: false
      t.decimal :stop_loss, precision: 15, scale: 5
      t.decimal :take_profit, precision: 15, scale: 5
      %i[commission swap profit net_profit].each do |column|
        t.decimal column, precision: 15, scale: 2, null: false, default: 0
      end
      t.string :comment

      t.timestamps
    end
    add_index :trades, %i[account_id position_id], unique: true
    add_index :trades, %i[account_id closed_at]
    add_index :trades, %i[account_id symbol]
  end
end
