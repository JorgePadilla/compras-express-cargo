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

ActiveRecord::Schema[8.0].define(version: 2026_03_31_051755) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "carriers", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "tipo"
    t.boolean "activo", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categoria_precios", force: :cascade do |t|
    t.string "nombre", null: false
    t.decimal "precio_libra_aereo", precision: 10, scale: 2
    t.decimal "precio_libra_maritimo", precision: 10, scale: 2
    t.decimal "precio_volumen", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "clientes", force: :cascade do |t|
    t.string "codigo", null: false
    t.string "nombre", null: false
    t.string "apellido"
    t.string "identidad"
    t.string "email"
    t.string "telefono"
    t.string "telefono_whatsapp"
    t.text "direccion"
    t.string "ciudad"
    t.string "departamento"
    t.decimal "saldo_pendiente", precision: 10, scale: 2, default: "0.0"
    t.bigint "categoria_precio_id"
    t.boolean "correo_enviado", default: false
    t.boolean "correo_confirmado", default: false
    t.boolean "activo", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activo"], name: "index_clientes_on_activo"
    t.index ["categoria_precio_id"], name: "index_clientes_on_categoria_precio_id"
    t.index ["codigo"], name: "index_clientes_on_codigo", unique: true
    t.index ["email"], name: "index_clientes_on_email"
  end

  create_table "configuracions", force: :cascade do |t|
    t.string "clave", null: false
    t.text "valor"
    t.string "tipo"
    t.string "categoria"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clave"], name: "index_configuracions_on_clave", unique: true
  end

  create_table "consignatarios", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "identidad"
    t.text "direccion"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "empresa_manifiestos", force: :cascade do |t|
    t.string "nombre", null: false
    t.boolean "activo", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lugars", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "tipo"
    t.text "direccion"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tamano_cajas", force: :cascade do |t|
    t.string "nombre", null: false
    t.decimal "largo", precision: 8, scale: 2
    t.decimal "ancho", precision: 8, scale: 2
    t.decimal "alto", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tipo_envios", force: :cascade do |t|
    t.string "nombre", null: false
    t.string "codigo"
    t.boolean "activo", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nombre", default: "", null: false
    t.string "rol", default: "digitador_miami", null: false
    t.string "ubicacion", default: "honduras"
    t.boolean "activo", default: true, null: false
    t.index ["activo"], name: "index_users_on_activo"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["rol"], name: "index_users_on_rol"
    t.index ["ubicacion"], name: "index_users_on_ubicacion"
  end

  add_foreign_key "clientes", "categoria_precios"
  add_foreign_key "sessions", "users"
end
