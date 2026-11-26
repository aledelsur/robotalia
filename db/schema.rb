# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_26_080006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_imports", force: :cascade do |t|
    t.bigint "account_id"
    t.string "status", default: "queued", null: false
    t.integer "new_count", default: 0, null: false
    t.integer "updated_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.integer "error_count", default: 0, null: false
    t.jsonb "error_messages", default: [], null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_imports_on_account_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "broker"
    t.string "server", default: "", null: false
    t.string "login", null: false
    t.string "currency", limit: 3, null: false
    t.decimal "initial_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.boolean "demo", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["login", "server", "demo"], name: "index_accounts_on_login_and_server_and_demo", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "balance_operations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "ticket", null: false
    t.datetime "executed_at", null: false
    t.string "kind", null: false
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "ticket"], name: "index_balance_operations_on_account_id_and_ticket", unique: true
  end

  create_table "deals", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "ticket", null: false
    t.bigint "order_ticket"
    t.datetime "executed_at", null: false
    t.string "symbol", null: false
    t.string "side", null: false
    t.string "direction", null: false
    t.decimal "volume", precision: 12, scale: 2, null: false
    t.decimal "price", precision: 15, scale: 5, null: false
    t.decimal "commission", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "fee", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "swap", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "profit", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "balance", precision: 15, scale: 2
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "order_ticket"], name: "index_deals_on_account_id_and_order_ticket"
    t.index ["account_id", "ticket"], name: "index_deals_on_account_id_and_ticket", unique: true
  end

  create_table "robots", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "key"], name: "index_robots_on_account_id_and_key", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "robot_id"
    t.bigint "position_id", null: false
    t.string "symbol", null: false
    t.string "side", null: false
    t.decimal "volume", precision: 12, scale: 2, null: false
    t.datetime "opened_at", null: false
    t.datetime "closed_at", null: false
    t.decimal "open_price", precision: 15, scale: 5, null: false
    t.decimal "close_price", precision: 15, scale: 5, null: false
    t.decimal "stop_loss", precision: 15, scale: 5
    t.decimal "take_profit", precision: 15, scale: 5
    t.decimal "commission", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "swap", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "profit", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "net_profit", precision: 15, scale: 2, default: "0.0", null: false
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "closed_at"], name: "index_trades_on_account_id_and_closed_at"
    t.index ["account_id", "position_id"], name: "index_trades_on_account_id_and_position_id", unique: true
    t.index ["account_id", "symbol"], name: "index_trades_on_account_id_and_symbol"
    t.index ["robot_id"], name: "index_trades_on_robot_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "demo", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["demo"], name: "index_users_on_demo", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "account_imports", "accounts"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "balance_operations", "accounts"
  add_foreign_key "deals", "accounts"
  add_foreign_key "robots", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "trades", "accounts"
  add_foreign_key "trades", "robots"
end
