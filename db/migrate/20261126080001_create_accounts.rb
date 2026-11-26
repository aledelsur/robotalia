class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :broker
      t.string :server, null: false, default: ""
      t.string :login, null: false
      t.string :currency, null: false, limit: 3
      t.decimal :initial_balance, precision: 15, scale: 2, null: false, default: 0
      t.boolean :demo, null: false, default: false

      t.timestamps
    end
    add_index :accounts, %i[login server demo], unique: true
  end
end
