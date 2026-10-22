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

ActiveRecord::Schema[8.1].define(version: 2026_10_21_195931) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.integer "cart_id", null: false
    t.datetime "created_at", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.integer "variant_id", null: false
    t.index ["cart_id", "variant_id"], name: "index_cart_items_on_cart_id_and_variant_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["variant_id"], name: "index_cart_items_on_variant_id"
  end

  create_table "carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_carts_on_token", unique: true
  end

  create_table "deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.integer "newsletter_id", null: false
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.integer "subscriber_id", null: false
    t.datetime "updated_at", null: false
    t.index ["newsletter_id", "subscriber_id"], name: "index_deliveries_on_newsletter_id_and_subscriber_id", unique: true
    t.index ["newsletter_id"], name: "index_deliveries_on_newsletter_id"
    t.index ["subscriber_id"], name: "index_deliveries_on_subscriber_id"
  end

  create_table "newsletters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_id", null: false
    t.integer "quantity", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.integer "variant_id"
    t.string "variant_name", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["variant_id"], name: "index_order_items_on_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "buyer_email"
    t.string "buyer_name"
    t.datetime "created_at", null: false
    t.string "shipping_address1"
    t.string "shipping_address2"
    t.integer "shipping_cents", default: 0, null: false
    t.string "shipping_city"
    t.string "shipping_country"
    t.string "shipping_name"
    t.string "shipping_state"
    t.string "shipping_zip"
    t.string "status", default: "pending", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_orders_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_orders_on_stripe_checkout_session_id", unique: true, where: "stripe_checkout_session_id IS NOT NULL"
  end

  create_table "photos", force: :cascade do |t|
    t.string "caption"
    t.datetime "created_at", null: false
    t.integer "position", default: 1, null: false
    t.boolean "published", default: true, null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "featured", default: false, null: false
    t.string "name", null: false
    t.boolean "published", default: false, null: false
    t.datetime "updated_at", null: false
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shows", force: :cascade do |t|
    t.string "bandsintown_id"
    t.string "bandsintown_url"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at"
    t.boolean "featured", default: false, null: false
    t.boolean "free", default: false, null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.json "lineup"
    t.decimal "longitude", precision: 10, scale: 6
    t.json "offers"
    t.string "region"
    t.string "source", default: "bandsintown", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "active", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "venue_name"
    t.index ["bandsintown_id"], name: "index_shows_on_bandsintown_id", unique: true
    t.index ["starts_at"], name: "index_shows_on_starts_at"
    t.index ["status"], name: "index_shows_on_status"
  end

  create_table "stripe_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "processed_at", null: false
    t.string "stripe_event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_event_id"], name: "index_stripe_events_on_stripe_event_id", unique: true
  end

  create_table "subscribers", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "unsubscribed_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_subscribers_on_email", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "price_cents", default: 0, null: false
    t.integer "product_id", null: false
    t.string "sku"
    t.integer "stock_quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "weight_oz", default: 0, null: false
    t.index "product_id, lower(name)", name: "index_variants_on_product_id_and_lower_name", unique: true
    t.index ["product_id", "position"], name: "index_variants_on_product_id_and_position"
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["sku"], name: "index_variants_on_sku", unique: true, where: "sku IS NOT NULL"
  end

  create_table "videos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "published_at", null: false
    t.boolean "short", default: false, null: false
    t.string "thumbnail_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true, null: false
    t.string "youtube_id", null: false
    t.index ["published_at"], name: "index_videos_on_published_at"
    t.index ["youtube_id"], name: "index_videos_on_youtube_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "variants"
  add_foreign_key "deliveries", "newsletters"
  add_foreign_key "deliveries", "subscribers"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "variants"
  add_foreign_key "sessions", "users"
  add_foreign_key "variants", "products"
end
