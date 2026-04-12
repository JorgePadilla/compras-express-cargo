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

ActiveRecord::Schema[8.0].define(version: 2026_04_12_060600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "aperturas_caja", force: :cascade do |t|
    t.string "numero", null: false
    t.date "fecha", null: false
    t.string "estado", default: "abierta", null: false
    t.decimal "monto_apertura", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "monto_cierre", precision: 10, scale: 2
    t.decimal "total_pagos", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_ingresos", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_egresos", precision: 10, scale: 2, default: "0.0"
    t.decimal "diferencia", precision: 10, scale: 2
    t.text "notas_apertura"
    t.text "notas_cierre"
    t.bigint "abierta_por_id", null: false
    t.bigint "cerrada_por_id"
    t.datetime "cerrada_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abierta_por_id"], name: "index_aperturas_caja_on_abierta_por_id"
    t.index ["cerrada_por_id"], name: "index_aperturas_caja_on_cerrada_por_id"
    t.index ["estado"], name: "index_aperturas_caja_on_estado"
    t.index ["fecha"], name: "index_aperturas_caja_on_fecha", unique: true
    t.index ["numero"], name: "index_aperturas_caja_on_numero", unique: true
  end

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
    t.boolean "notificar_facturas", default: true, null: false
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

  create_table "cotizacion_items", force: :cascade do |t|
    t.bigint "cotizacion_id", null: false
    t.bigint "paquete_id"
    t.string "concepto", null: false
    t.decimal "cantidad", precision: 10, scale: 2, default: "1.0"
    t.decimal "precio_unitario", precision: 10, scale: 2, default: "0.0"
    t.decimal "peso_cobrar", precision: 10, scale: 2
    t.decimal "precio_libra", precision: 10, scale: 2
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cotizacion_id"], name: "index_cotizacion_items_on_cotizacion_id"
    t.index ["paquete_id"], name: "index_cotizacion_items_on_paquete_id"
  end

  create_table "cotizaciones", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "cliente_id", null: false
    t.string "estado", default: "borrador", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "impuesto", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "moneda", default: "LPS", null: false
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.text "notas"
    t.text "terminos"
    t.integer "vigencia_dias", default: 30
    t.date "fecha_vencimiento"
    t.bigint "creado_por_id"
    t.datetime "enviada_at"
    t.datetime "aceptada_at"
    t.datetime "rechazada_at"
    t.datetime "email_enviado_at"
    t.bigint "venta_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cliente_id"], name: "index_cotizaciones_on_cliente_id"
    t.index ["creado_por_id"], name: "index_cotizaciones_on_creado_por_id"
    t.index ["estado"], name: "index_cotizaciones_on_estado"
    t.index ["numero"], name: "index_cotizaciones_on_numero", unique: true
    t.index ["venta_id"], name: "index_cotizaciones_on_venta_id"
  end

  create_table "egresos_caja", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "apertura_caja_id", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.string "concepto", null: false
    t.string "metodo_pago", null: false
    t.string "categoria"
    t.text "notas"
    t.bigint "registrado_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["apertura_caja_id"], name: "index_egresos_caja_on_apertura_caja_id"
    t.index ["numero"], name: "index_egresos_caja_on_numero", unique: true
    t.index ["registrado_por_id"], name: "index_egresos_caja_on_registrado_por_id"
  end

  create_table "empresa_manifiestos", force: :cascade do |t|
    t.string "nombre", null: false
    t.boolean "activo", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "empresas", force: :cascade do |t|
    t.string "nombre", default: "Compras Express Cargo", null: false
    t.string "rtn"
    t.string "telefono"
    t.string "email_contacto"
    t.text "direccion"
    t.string "ciudad", default: "San Pedro Sula"
    t.string "pais", default: "Honduras"
    t.string "moneda_default", default: "LPS"
    t.decimal "isv_rate", precision: 5, scale: 4, default: "0.15"
    t.string "sitio_web"
    t.text "terminos_factura"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "entrega_paquetes", force: :cascade do |t|
    t.bigint "entrega_id", null: false
    t.bigint "paquete_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entrega_id", "paquete_id"], name: "index_entrega_paquetes_on_entrega_id_and_paquete_id", unique: true
    t.index ["entrega_id"], name: "index_entrega_paquetes_on_entrega_id"
    t.index ["paquete_id"], name: "index_entrega_paquetes_on_paquete_id"
  end

  create_table "entregas", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "cliente_id", null: false
    t.string "tipo_entrega", default: "retiro_oficina", null: false
    t.string "estado", default: "pendiente", null: false
    t.string "receptor_nombre", null: false
    t.string "receptor_identidad", null: false
    t.text "direccion_entrega"
    t.bigint "repartidor_id"
    t.bigint "creado_por_id"
    t.text "notas"
    t.datetime "despachado_at"
    t.datetime "entregado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cliente_id"], name: "index_entregas_on_cliente_id"
    t.index ["creado_por_id"], name: "index_entregas_on_creado_por_id"
    t.index ["estado"], name: "index_entregas_on_estado"
    t.index ["numero"], name: "index_entregas_on_numero", unique: true
    t.index ["repartidor_id"], name: "index_entregas_on_repartidor_id"
    t.index ["tipo_entrega"], name: "index_entregas_on_tipo_entrega"
  end

  create_table "financiamiento_cuotas", force: :cascade do |t|
    t.bigint "financiamiento_id", null: false
    t.integer "numero_cuota", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.string "estado", default: "pendiente", null: false
    t.date "fecha_vencimiento", null: false
    t.datetime "pagada_at"
    t.bigint "pago_id"
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["financiamiento_id", "numero_cuota"], name: "idx_fin_cuotas_unique", unique: true
    t.index ["financiamiento_id"], name: "index_financiamiento_cuotas_on_financiamiento_id"
    t.index ["pago_id"], name: "index_financiamiento_cuotas_on_pago_id"
  end

  create_table "financiamientos", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "venta_id", null: false
    t.bigint "cliente_id", null: false
    t.string "estado", default: "activo", null: false
    t.integer "numero_cuotas", null: false
    t.decimal "monto_total", precision: 10, scale: 2, null: false
    t.decimal "monto_cuota", precision: 10, scale: 2, null: false
    t.string "moneda", default: "LPS", null: false
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.string "frecuencia", default: "mensual", null: false
    t.date "fecha_inicio", null: false
    t.text "notas"
    t.bigint "creado_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cliente_id"], name: "index_financiamientos_on_cliente_id"
    t.index ["creado_por_id"], name: "index_financiamientos_on_creado_por_id"
    t.index ["estado"], name: "index_financiamientos_on_estado"
    t.index ["numero"], name: "index_financiamientos_on_numero", unique: true
    t.index ["venta_id"], name: "index_financiamientos_on_venta_id"
  end

  create_table "ingresos_caja", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "apertura_caja_id", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.string "concepto", null: false
    t.string "metodo_pago", null: false
    t.text "notas"
    t.bigint "registrado_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["apertura_caja_id"], name: "index_ingresos_caja_on_apertura_caja_id"
    t.index ["numero"], name: "index_ingresos_caja_on_numero", unique: true
    t.index ["registrado_por_id"], name: "index_ingresos_caja_on_registrado_por_id"
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

  create_table "nota_credito_items", force: :cascade do |t|
    t.bigint "nota_credito_id", null: false
    t.bigint "paquete_id"
    t.string "concepto", null: false
    t.decimal "peso_cobrar", precision: 10, scale: 2
    t.decimal "precio_libra", precision: 10, scale: 2
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["nota_credito_id"], name: "index_nota_credito_items_on_nota_credito_id"
    t.index ["paquete_id"], name: "index_nota_credito_items_on_paquete_id"
  end

  create_table "nota_debito_items", force: :cascade do |t|
    t.bigint "nota_debito_id", null: false
    t.bigint "paquete_id"
    t.string "concepto", null: false
    t.decimal "peso_cobrar", precision: 10, scale: 2
    t.decimal "precio_libra", precision: 10, scale: 2
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["nota_debito_id"], name: "index_nota_debito_items_on_nota_debito_id"
    t.index ["paquete_id"], name: "index_nota_debito_items_on_paquete_id"
  end

  create_table "notas_credito", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "venta_id", null: false
    t.bigint "cliente_id", null: false
    t.string "estado", default: "creado", null: false
    t.string "motivo", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "impuesto", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "moneda", default: "LPS", null: false
    t.text "notas"
    t.bigint "creado_por_id"
    t.datetime "emitido_at"
    t.datetime "anulado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.index ["cliente_id"], name: "index_notas_credito_on_cliente_id"
    t.index ["creado_por_id"], name: "index_notas_credito_on_creado_por_id"
    t.index ["estado"], name: "index_notas_credito_on_estado"
    t.index ["numero"], name: "index_notas_credito_on_numero", unique: true
    t.index ["venta_id"], name: "index_notas_credito_on_venta_id"
  end

  create_table "notas_debito", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "venta_id", null: false
    t.bigint "cliente_id", null: false
    t.string "estado", default: "creado", null: false
    t.string "motivo", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "impuesto", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "moneda", default: "LPS", null: false
    t.text "notas"
    t.bigint "creado_por_id"
    t.datetime "emitido_at"
    t.datetime "anulado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.index ["cliente_id"], name: "index_notas_debito_on_cliente_id"
    t.index ["creado_por_id"], name: "index_notas_debito_on_creado_por_id"
    t.index ["estado"], name: "index_notas_debito_on_estado"
    t.index ["numero"], name: "index_notas_debito_on_numero", unique: true
    t.index ["venta_id"], name: "index_notas_debito_on_venta_id"
  end

  create_table "pagos", force: :cascade do |t|
    t.bigint "venta_id", null: false
    t.bigint "cliente_id", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.string "metodo_pago", null: false
    t.string "moneda", default: "LPS", null: false
    t.string "estado", default: "completado", null: false
    t.datetime "pagado_at"
    t.text "notas"
    t.bigint "registrado_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.bigint "apertura_caja_id"
    t.index ["apertura_caja_id"], name: "index_pagos_on_apertura_caja_id"
    t.index ["cliente_id"], name: "index_pagos_on_cliente_id"
    t.index ["estado"], name: "index_pagos_on_estado"
    t.index ["registrado_por_id"], name: "index_pagos_on_registrado_por_id"
    t.index ["venta_id"], name: "index_pagos_on_venta_id"
  end

  create_table "paquetes", force: :cascade do |t|
    t.string "tracking", null: false
    t.string "guia", null: false
    t.bigint "cliente_id", null: false
    t.bigint "manifiesto_id"
    t.bigint "tipo_envio_id"
    t.string "estado", default: "recibido_miami", null: false
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
    t.bigint "pre_factura_id"
    t.bigint "venta_id"
    t.bigint "entrega_id"
    t.index ["cliente_id"], name: "index_paquetes_on_cliente_id"
    t.index ["entrega_id"], name: "index_paquetes_on_entrega_id"
    t.index ["estado"], name: "index_paquetes_on_estado"
    t.index ["guia"], name: "index_paquetes_on_guia", unique: true
    t.index ["manifiesto_id"], name: "index_paquetes_on_manifiesto_id"
    t.index ["pre_factura_id"], name: "index_paquetes_on_pre_factura_id"
    t.index ["tipo_envio_id"], name: "index_paquetes_on_tipo_envio_id"
    t.index ["tracking"], name: "index_paquetes_on_tracking"
    t.index ["user_id"], name: "index_paquetes_on_user_id"
    t.index ["venta_id"], name: "index_paquetes_on_venta_id"
  end

  create_table "pre_alerta_paquetes", force: :cascade do |t|
    t.bigint "pre_alerta_id", null: false
    t.bigint "paquete_id"
    t.string "tracking", null: false
    t.text "descripcion"
    t.date "fecha"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "instrucciones"
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
    t.string "titulo"
    t.string "proveedor"
    t.index ["cliente_id"], name: "index_pre_alertas_on_cliente_id"
    t.index ["creado_por_tipo", "creado_por_id"], name: "index_pre_alertas_on_creado_por_tipo_and_creado_por_id"
    t.index ["deleted_at"], name: "index_pre_alertas_on_deleted_at"
    t.index ["estado"], name: "index_pre_alertas_on_estado"
    t.index ["numero_documento"], name: "index_pre_alertas_on_numero_documento", unique: true
    t.index ["tipo_envio_id"], name: "index_pre_alertas_on_tipo_envio_id"
  end

  create_table "pre_factura_items", force: :cascade do |t|
    t.bigint "pre_factura_id", null: false
    t.bigint "paquete_id"
    t.string "concepto", null: false
    t.decimal "peso_cobrar", precision: 10, scale: 2
    t.decimal "precio_libra", precision: 10, scale: 2
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["paquete_id"], name: "index_pre_factura_items_on_paquete_id"
    t.index ["pre_factura_id"], name: "index_pre_factura_items_on_pre_factura_id"
  end

  create_table "pre_facturas", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "cliente_id", null: false
    t.string "estado", default: "creado", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "impuesto", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "moneda", default: "LPS", null: false
    t.date "fecha_trabajo"
    t.text "notas"
    t.bigint "creado_por_id"
    t.datetime "confirmado_at"
    t.datetime "facturado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.index ["cliente_id"], name: "index_pre_facturas_on_cliente_id"
    t.index ["creado_por_id"], name: "index_pre_facturas_on_creado_por_id"
    t.index ["estado"], name: "index_pre_facturas_on_estado"
    t.index ["numero"], name: "index_pre_facturas_on_numero", unique: true
  end

  create_table "recibos", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "venta_id", null: false
    t.bigint "pago_id", null: false
    t.bigint "cliente_id", null: false
    t.decimal "monto", precision: 10, scale: 2, null: false
    t.string "forma_pago"
    t.string "moneda", default: "LPS", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.index ["cliente_id"], name: "index_recibos_on_cliente_id"
    t.index ["numero"], name: "index_recibos_on_numero", unique: true
    t.index ["pago_id"], name: "index_recibos_on_pago_id"
    t.index ["venta_id"], name: "index_recibos_on_venta_id"
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
    t.boolean "con_reempaque", default: false, null: false
    t.boolean "consolidable", default: false, null: false
    t.decimal "precio_libra", precision: 10, scale: 2
    t.string "modalidad"
    t.string "sla"
    t.integer "max_paquetes_por_accion"
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

  create_table "venta_items", force: :cascade do |t|
    t.bigint "venta_id", null: false
    t.bigint "paquete_id"
    t.string "concepto", null: false
    t.decimal "peso_cobrar", precision: 10, scale: 2
    t.decimal "precio_libra", precision: 10, scale: 2
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["paquete_id"], name: "index_venta_items_on_paquete_id"
    t.index ["venta_id"], name: "index_venta_items_on_venta_id"
  end

  create_table "ventas", force: :cascade do |t|
    t.string "numero", null: false
    t.bigint "cliente_id", null: false
    t.bigint "pre_factura_id"
    t.string "estado", default: "pendiente", null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "impuesto", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.decimal "saldo_pendiente", precision: 10, scale: 2, default: "0.0"
    t.string "moneda", default: "LPS", null: false
    t.text "notas"
    t.bigint "creado_por_id"
    t.datetime "pagada_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "email_pendiente_enviado_at"
    t.datetime "email_pagada_enviado_at"
    t.decimal "tasa_cambio_aplicada", precision: 10, scale: 4
    t.bigint "financiamiento_id"
    t.index ["cliente_id"], name: "index_ventas_on_cliente_id"
    t.index ["creado_por_id"], name: "index_ventas_on_creado_por_id"
    t.index ["estado"], name: "index_ventas_on_estado"
    t.index ["financiamiento_id"], name: "index_ventas_on_financiamiento_id"
    t.index ["numero"], name: "index_ventas_on_numero", unique: true
    t.index ["pre_factura_id"], name: "index_ventas_on_pre_factura_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "aperturas_caja", "users", column: "abierta_por_id"
  add_foreign_key "aperturas_caja", "users", column: "cerrada_por_id"
  add_foreign_key "cliente_sessions", "clientes"
  add_foreign_key "clientes", "categoria_precios"
  add_foreign_key "cotizacion_items", "cotizaciones"
  add_foreign_key "cotizacion_items", "paquetes"
  add_foreign_key "cotizaciones", "clientes"
  add_foreign_key "cotizaciones", "users", column: "creado_por_id"
  add_foreign_key "cotizaciones", "ventas"
  add_foreign_key "egresos_caja", "aperturas_caja"
  add_foreign_key "egresos_caja", "users", column: "registrado_por_id"
  add_foreign_key "entrega_paquetes", "entregas"
  add_foreign_key "entrega_paquetes", "paquetes"
  add_foreign_key "entregas", "clientes"
  add_foreign_key "entregas", "users", column: "creado_por_id"
  add_foreign_key "entregas", "users", column: "repartidor_id"
  add_foreign_key "financiamiento_cuotas", "financiamientos"
  add_foreign_key "financiamiento_cuotas", "pagos"
  add_foreign_key "financiamientos", "clientes"
  add_foreign_key "financiamientos", "users", column: "creado_por_id"
  add_foreign_key "financiamientos", "ventas"
  add_foreign_key "ingresos_caja", "aperturas_caja"
  add_foreign_key "ingresos_caja", "users", column: "registrado_por_id"
  add_foreign_key "manifiestos", "empresa_manifiestos"
  add_foreign_key "manifiestos", "users"
  add_foreign_key "nota_credito_items", "notas_credito"
  add_foreign_key "nota_credito_items", "paquetes"
  add_foreign_key "nota_debito_items", "notas_debito"
  add_foreign_key "nota_debito_items", "paquetes"
  add_foreign_key "notas_credito", "clientes"
  add_foreign_key "notas_credito", "users", column: "creado_por_id"
  add_foreign_key "notas_credito", "ventas"
  add_foreign_key "notas_debito", "clientes"
  add_foreign_key "notas_debito", "users", column: "creado_por_id"
  add_foreign_key "notas_debito", "ventas"
  add_foreign_key "pagos", "aperturas_caja"
  add_foreign_key "pagos", "clientes"
  add_foreign_key "pagos", "users", column: "registrado_por_id"
  add_foreign_key "pagos", "ventas"
  add_foreign_key "paquetes", "clientes"
  add_foreign_key "paquetes", "entregas"
  add_foreign_key "paquetes", "manifiestos"
  add_foreign_key "paquetes", "pre_facturas"
  add_foreign_key "paquetes", "tipo_envios"
  add_foreign_key "paquetes", "users"
  add_foreign_key "paquetes", "ventas"
  add_foreign_key "pre_alerta_paquetes", "paquetes"
  add_foreign_key "pre_alerta_paquetes", "pre_alertas"
  add_foreign_key "pre_alertas", "clientes"
  add_foreign_key "pre_alertas", "tipo_envios"
  add_foreign_key "pre_factura_items", "paquetes"
  add_foreign_key "pre_factura_items", "pre_facturas"
  add_foreign_key "pre_facturas", "clientes"
  add_foreign_key "pre_facturas", "users", column: "creado_por_id"
  add_foreign_key "recibos", "clientes"
  add_foreign_key "recibos", "pagos"
  add_foreign_key "recibos", "ventas"
  add_foreign_key "sessions", "users"
  add_foreign_key "venta_items", "paquetes"
  add_foreign_key "venta_items", "ventas"
  add_foreign_key "ventas", "clientes"
  add_foreign_key "ventas", "financiamientos"
  add_foreign_key "ventas", "pre_facturas"
  add_foreign_key "ventas", "users", column: "creado_por_id"
end
