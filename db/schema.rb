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

ActiveRecord::Schema[8.0].define(version: 2026_04_04_060005) do
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

  create_table "cliente_sessions", force: :cascade do |t|
    t.bigint "cliente_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cliente_id"], name: "index_cliente_sessions_on_cliente_id"
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
    t.text "notas_miami"
    t.text "notas_honduras"
    t.string "password_digest"
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

  create_table "manifiestos", force: :cascade do |t|
    t.string "numero", null: false
    t.string "numero_caja"
    t.string "numero_guia"
    t.bigint "empresa_manifiesto_id"
    t.string "estado", default: "creado", null: false
    t.string "tipo_envio"
    t.string "expedido_por"
    t.integer "cantidad_paquetes", default: 0
    t.decimal "volumen_total", precision: 10, scale: 2
    t.decimal "peso_total", precision: 10, scale: 2
    t.datetime "fecha_enviado"
    t.datetime "fecha_aduana"
    t.bigint "user_id"
    t.boolean "activo", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["empresa_manifiesto_id"], name: "index_manifiestos_on_empresa_manifiesto_id"
    t.index ["estado"], name: "index_manifiestos_on_estado"
    t.index ["numero"], name: "index_manifiestos_on_numero", unique: true
    t.index ["user_id"], name: "index_manifiestos_on_user_id"
  end

  create_table "paquetes", force: :cascade do |t|
    t.string "tracking", null: false
    t.string "guia", null: false
    t.bigint "cliente_id", null: false
    t.bigint "manifiesto_id"
    t.bigint "tipo_envio_id"
    t.string "estado", default: "recibido", null: false
    t.decimal "peso", precision: 10, scale: 2
    t.decimal "volumen", precision: 10, scale: 2
    t.decimal "precio_libra", precision: 10, scale: 2
    t.decimal "monto_total", precision: 10, scale: 2
    t.decimal "alto", precision: 8, scale: 2
    t.decimal "largo", precision: 8, scale: 2
    t.decimal "ancho", precision: 8, scale: 2
    t.decimal "peso_volumetrico", precision: 10, scale: 2
    t.decimal "peso_cobrar", precision: 10, scale: 2
    t.integer "cantidad_productos"
    t.integer "cantidad_paquetes"
    t.integer "numero_caja"
    t.text "descripcion"
    t.string "remitente"
    t.string "expedido_por"
    t.string "proveedor"
    t.text "notas_internas"
    t.boolean "pre_alerta", default: false
    t.boolean "pre_factura", default: false
    t.boolean "solicito_cambio_servicio", default: false
    t.boolean "retener_miami", default: false
    t.datetime "fecha_recibido_miami"
    t.datetime "fecha_enviado"
    t.datetime "fecha_llegada_hn"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cliente_id"], name: "index_paquetes_on_cliente_id"
    t.index ["estado"], name: "index_paquetes_on_estado"
    t.index ["guia"], name: "index_paquetes_on_guia", unique: true
    t.index ["manifiesto_id"], name: "index_paquetes_on_manifiesto_id"
    t.index ["tipo_envio_id"], name: "index_paquetes_on_tipo_envio_id"
    t.index ["tracking"], name: "index_paquetes_on_tracking"
    t.index ["user_id"], name: "index_paquetes_on_user_id"
  end

  create_table "pre_alerta_paquetes", force: :cascade do |t|
    t.bigint "pre_alerta_id", null: false
    t.bigint "paquete_id"
    t.string "tracking", null: false
    t.text "descripcion"
    t.boolean "retener_miami", default: false
    t.date "fecha"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["paquete_id"], name: "index_pre_alerta_paquetes_on_paquete_id"
    t.index ["pre_alerta_id", "tracking"], name: "index_pre_alerta_paquetes_on_pre_alerta_id_and_tracking", unique: true
    t.index ["pre_alerta_id"], name: "index_pre_alerta_paquetes_on_pre_alerta_id"
    t.index ["tracking"], name: "index_pre_alerta_paquetes_on_tracking"
  end

  create_table "pre_alertas", force: :cascade do |t|
    t.string "numero_documento", null: false
    t.bigint "cliente_id", null: false
    t.bigint "tipo_envio_id", null: false
    t.boolean "consolidado", default: false
    t.boolean "con_reempaque", default: false
    t.text "notas_grupo"
    t.string "estado", default: "pre_alerta", null: false
    t.boolean "notificado", default: false
    t.string "creado_por_tipo"
    t.bigint "creado_por_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cliente_id"], name: "index_pre_alertas_on_cliente_id"
    t.index ["creado_por_tipo", "creado_por_id"], name: "index_pre_alertas_on_creado_por_tipo_and_creado_por_id"
    t.index ["deleted_at"], name: "index_pre_alertas_on_deleted_at"
    t.index ["estado"], name: "index_pre_alertas_on_estado"
    t.index ["numero_documento"], name: "index_pre_alertas_on_numero_documento", unique: true
    t.index ["tipo_envio_id"], name: "index_pre_alertas_on_tipo_envio_id"
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

  add_foreign_key "cliente_sessions", "clientes"
  add_foreign_key "clientes", "categoria_precios"
  add_foreign_key "manifiestos", "empresa_manifiestos"
  add_foreign_key "manifiestos", "users"
  add_foreign_key "paquetes", "clientes"
  add_foreign_key "paquetes", "manifiestos"
  add_foreign_key "paquetes", "tipo_envios"
  add_foreign_key "paquetes", "users"
  add_foreign_key "pre_alerta_paquetes", "paquetes"
  add_foreign_key "pre_alerta_paquetes", "pre_alertas"
  add_foreign_key "pre_alertas", "clientes"
  add_foreign_key "pre_alertas", "tipo_envios"
  add_foreign_key "sessions", "users"
end
