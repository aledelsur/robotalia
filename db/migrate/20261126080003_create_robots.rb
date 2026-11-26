class CreateRobots < ActiveRecord::Migration[8.1]
  def change
    create_table :robots do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.string :key, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :robots, %i[account_id key], unique: true
  end
end
