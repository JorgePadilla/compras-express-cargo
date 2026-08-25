# PR-D1.a: helpers para renderizar la bitácora (paper_trail versions) en
# las vistas. La tabla `versions` guarda `whodunnit` como string con el ID
# del User. Acá resolvemos el User para mostrar nombre + iniciales.
module AuditLogHelper
  # Roles autorizados a ver la bitácora (paper_trail versions). Decisión
  # Yusef 2026-04-29: admin + TODOS los supervisores. Excluye SAC, cajero,
  # digitador, entrega_despacho. Centralizado acá para evitar duplicar la
  # lista en cada vista que muestre bitácora.
  AUDIT_LOG_ROLES = %w[supervisor_miami supervisor_caja supervisor_prefactura].freeze

  def can_view_audit_log?
    user = Current.user
    return false unless user
    return true if user.admin?
    AUDIT_LOG_ROLES.include?(user.rol)
  end

  # Carga eficiente de los users referenciados por una colección de versions
  # para evitar N+1. Devuelve un hash {user_id_string => User}. Una sola
  # query por toda la colección de versions, sin importar cuántas filas
  # apunten al mismo whodunnit.
  def audit_users_index(versions)
    return {} if versions.blank?
    ids = versions.map(&:whodunnit).compact_blank.uniq
    return {} if ids.empty?
    User.where(id: ids).index_by { |u| u.id.to_s }
  end

  # Devuelve el User que disparó la version, o nil si whodunnit es blank
  # o el user fue eliminado. **Nunca hace queries por su cuenta** — sólo
  # consulta el índice precargado por audit_users_index. Esto garantiza
  # que no se cuele un N+1 aunque el caller olvide preloadear (peor caso:
  # devuelve nil y se renderiza "Sistema").
  def audit_user_for(version, users_by_id = {})
    return nil if version.whodunnit.blank?
    users_by_id[version.whodunnit]
  end

  # Etiqueta legible del evento: "creó", "actualizó", "eliminó".
  def audit_event_label(event)
    case event
    when "create"  then "creó"
    when "update"  then "actualizó"
    when "destroy" then "eliminó"
    else event.to_s
    end
  end

  # Lista de cambios humanos para una version. `object_changes` viene como
  # YAML serializado por paper_trail con `{column => [old, new]}`.
  # Filtra columnas ruidosas (timestamps).
  AUDIT_NOISY_COLUMNS = %w[updated_at created_at].freeze

  def audit_changes_summary(version, max: 5)
    return "" if version.event != "update" || version.object_changes.blank?
    changes = version.changeset rescue {}
    changes = changes.except(*AUDIT_NOISY_COLUMNS)
    return "Sin cambios significativos" if changes.empty?

    lines = changes.first(max).map do |column, (old_val, new_val)|
      "#{column}: #{audit_value(old_val)} → #{audit_value(new_val)}"
    end
    extra = changes.size > max ? " (+#{changes.size - max} más)" : ""
    lines.join(" · ") + extra
  end

  def audit_value(v)
    case v
    when nil   then "—"
    when ""    then "(vacío)"
    when Date, DateTime, Time, ActiveSupport::TimeWithZone then v.strftime("%Y-%m-%d %H:%M")
    else            v.to_s.truncate(40)
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # PR Bitácora overhaul (2026-05-02): diccionario de labels humanos
  # + FK resolvers para que las versions se lean en lenguaje natural
  # en lugar de "cliente_id: 12 → 34".
  # ─────────────────────────────────────────────────────────────────

  COLUMN_LABELS = {
    # Identificadores y estado
    "estado"               => "Estado",
    "tracking"             => "Tracking",
    "tracking_secundario"  => "Tracking secundario",
    "guia"                 => "Guía",
    "numero"               => "N° Documento",
    "numero_documento"     => "N° Documento",
    "numero_recepcion"     => "N° Recepción",
    "numero_caja"          => "N° Caja",
    "numero_guia"          => "N° Guía",
    "cantidad_paquetes"    => "Cant. paquetes",
    "cantidad_productos"   => "Cant. productos",
    "volumen_total"        => "Volumen total",
    "peso_total"           => "Peso total",
    "tipo_envio"           => "Tipo de envío",

    # Pesos y dimensiones
    "peso"                 => "Peso (lbs)",
    "alto"                 => "Alto",
    "largo"                => "Largo",
    "ancho"                => "Ancho",
    "peso_volumetrico"     => "Peso volumétrico",
    "peso_cobrar"          => "Peso a cobrar",

    # Asociaciones (FK)
    "cliente_id"             => "Cliente",
    "tipo_envio_id"          => "Tipo de envío",
    "manifiesto_id"          => "Manifiesto",
    "sucursal_id"            => "Sucursal destino",
    "sucursal_origen_id"     => "Sucursal origen",
    "sucursal_actual_id"     => "Sucursal actual",
    "sub_localidad_actual_id" => "Bodega interna",
    "warehouse_receipt_id"   => "Warehouse Receipt",
    "proveedor_id"           => "Proveedor",
    "user_id"                => "Usuario",
    "creado_por_id"          => "Creado por",
    "repartidor_id"          => "Repartidor",
    "pre_factura_id"         => "Pre-factura",
    "venta_id"               => "Venta / Factura",
    "entrega_id"             => "Entrega",
    "categoria_precio_id"    => "Categoría de precios",
    "empresa_manifiesto_id"  => "Empresa transportadora",
    "financiamiento_id"      => "Financiamiento",
    "tercero_id"             => "Tercero",

    # Texto libre
    "proveedor"            => "Proveedor (texto)",
    "expedido_por"         => "Carrier",
    "remitente"            => "Remitente",
    "descripcion"          => "Descripción",

    # Notas
    "notas_internas"       => "Notas internas",
    "notas_al_cliente"     => "Notas al cliente",
    "notas_consolidacion"  => "Notas de consolidación",
    "notas_retencion"      => "Notas de retención",
    "notas_caja"           => "Notas de Caja",
    "notas_sac"            => "Notas SAC",
    "notas_miami"          => "Notas Miami",
    "notas_honduras"       => "Notas Honduras",

    # Fechas (PR-D1)
    "fecha_recibido_miami"        => "Fecha recibido Miami",
    "fecha_empacado"              => "Fecha empacado",
    "fecha_enviado"               => "Fecha enviado",
    "fecha_aduana"                => "Fecha aduana",
    "fecha_consolidando"          => "Fecha consolidando",
    "fecha_disponible"            => "Fecha disponible",
    "fecha_disponible_programada" => "Fecha programada",
    "fecha_en_reparto"            => "Fecha en reparto",
    "fecha_entregado"             => "Fecha entregado",
    "fecha_pre_alerta"            => "Fecha pre-alerta",
    "fecha_solicito_recolecta"    => "Fecha solicitó recolecta",
    "fecha_posible_entrega"       => "Fecha posible entrega",

    # Recolecta + cambio servicio
    "recolecta_solicitada"     => "Solicitó recolecta",
    "recolecta_monto"          => "Monto recolecta",
    "recolecta_moneda"         => "Moneda recolecta",
    "solicito_cambio_servicio" => "Solicitó cambio de servicio",
    "retener_miami"            => "Retener en Miami",

    # Pre-alerta / Pre-factura flags
    "pre_alerta"  => "Flag pre-alerta",
    "pre_factura" => "Flag pre-factura",
    "consolidado" => "Consolidado",
    "con_reempaque" => "Con re-empaque",
    "notificado" => "Notificado",
    "finalizado" => "Finalizado",
    "creado_por_tipo" => "Creado por (tipo)",
    "deleted_at" => "Anulado en",

    # Cliente — datos personales / catálogo
    "codigo"             => "Código",
    "nombre"             => "Nombre",
    "apellido"           => "Apellido",
    "identidad"          => "Identidad / DNI",
    "rtn"                => "RTN",
    "email"              => "Email",
    "telefono"           => "Teléfono",
    "telefono_whatsapp"  => "WhatsApp",
    "direccion"          => "Dirección",
    "ciudad"             => "Ciudad",
    "departamento"       => "Departamento",
    "saldo_pendiente"    => "Saldo pendiente",
    "activo"             => "Activo",
    "notificar_facturas" => "Notificar facturas por email",
    "tema"               => "Tema (preferencia)",
    "correo_enviado"     => "Correo bienvenida enviado",
    "correo_confirmado"  => "Correo confirmado",

    # PreFactura / Venta — totales y montos (saldo_pendiente ya está
    # arriba en sección Cliente; queda mismo label).
    "subtotal"               => "Subtotal",
    "impuesto"               => "Impuesto",
    "total"                  => "Total",
    "moneda"                 => "Moneda",
    "tasa_cambio_aplicada"   => "Tasa de cambio aplicada",
    "fecha_trabajo"          => "Fecha de trabajo",
    "confirmado_at"          => "Confirmado en",
    "facturado_at"           => "Facturado en",
    "pagada_at"              => "Pagada en",
    "email_pendiente_enviado_at" => "Email pendiente enviado",
    "email_pagada_enviado_at"    => "Email pago confirmado enviado",

    # Entrega
    "tipo_entrega"       => "Tipo de entrega",
    "receptor_nombre"    => "Nombre del receptor",
    "receptor_identidad" => "Identidad del receptor",
    "direccion_entrega"  => "Dirección de entrega",
    "despachado_at"      => "Despachado en",
    "entregado_at"       => "Entregado en"
  }.freeze

  # Mapping FK column → resolver. Cada resolver es un Proc que recibe
  # un array de IDs y devuelve un hash {id => label_string}. Ejecuta
  # UNA query por modelo (no N+1).
  FK_RESOLVERS = {
    "cliente_id" => ->(ids) {
      Cliente.where(id: ids).each_with_object({}) { |c, h| h[c.id] = "#{c.codigo} — #{c.nombre_completo}" }
    },
    "user_id"    => ->(ids) {
      User.where(id: ids).each_with_object({}) { |u, h| h[u.id] = "#{u.nombre} (#{u.iniciales_display})" }
    },
    "tipo_envio_id" => ->(ids) {
      TipoEnvio.where(id: ids).each_with_object({}) { |t, h| h[t.id] = "#{t.codigo&.upcase} — #{t.nombre}" }
    },
    "manifiesto_id" => ->(ids) {
      Manifiesto.where(id: ids).each_with_object({}) { |m, h| h[m.id] = m.numero }
    },
    "sucursal_id"        => ->(ids) { Sucursal.where(id: ids).pluck(:id, :nombre).to_h },
    "sucursal_origen_id" => ->(ids) { Sucursal.where(id: ids).pluck(:id, :nombre).to_h },
    "sucursal_actual_id" => ->(ids) { Sucursal.where(id: ids).pluck(:id, :nombre).to_h },
    "warehouse_receipt_id" => ->(ids) {
      defined?(WarehouseReceipt) ? WarehouseReceipt.where(id: ids).pluck(:id, :receipt_number).to_h : {}
    },
    "proveedor_id" => ->(ids) {
      defined?(Proveedor) ? Proveedor.where(id: ids).pluck(:id, :nombre).to_h : {}
    },
    "pre_factura_id" => ->(ids) { PreFactura.where(id: ids).pluck(:id, :numero).to_h },
    "venta_id"       => ->(ids) { Venta.where(id: ids).pluck(:id, :numero).to_h },
    "entrega_id"     => ->(ids) { Entrega.where(id: ids).pluck(:id, :numero).to_h },
    "tercero_id"     => ->(ids) {
      Cliente.where(id: ids).each_with_object({}) { |c, h| h[c.id] = "#{c.codigo} — #{c.nombre_completo}" }
    },
    "creado_por_id" => ->(ids) {
      User.where(id: ids).each_with_object({}) { |u, h| h[u.id] = "#{u.nombre} (#{u.iniciales_display})" }
    },
    "repartidor_id" => ->(ids) {
      User.where(id: ids).each_with_object({}) { |u, h| h[u.id] = "#{u.nombre} (#{u.iniciales_display})" }
    },
    "categoria_precio_id" => ->(ids) {
      defined?(CategoriaPrecio) ? CategoriaPrecio.where(id: ids).pluck(:id, :nombre).to_h : {}
    },
    "empresa_manifiesto_id" => ->(ids) {
      defined?(EmpresaManifiesto) ? EmpresaManifiesto.where(id: ids).pluck(:id, :nombre).to_h : {}
    },
    "financiamiento_id" => ->(ids) {
      defined?(Financiamiento) ? Financiamiento.where(id: ids).pluck(:id, :numero).to_h : {}
    }
  }.freeze

  # Etiqueta humana de columna (usa COLUMN_LABELS o humaniza el nombre).
  def audit_column_label(column)
    COLUMN_LABELS[column.to_s] || column.to_s.humanize
  end

  # Pre-carga FK resolutions para todas las versions con UNA query por
  # modelo. Devuelve hash anidado { column => { id => label } }.
  # Llamar una sola vez por bitácora antes de iterar versions.
  def audit_fk_index(versions)
    fk_columns = FK_RESOLVERS.keys
    return {} if versions.blank?

    # Recolecta IDs por columna scaneando todos los changesets.
    ids_by_column = Hash.new { |h, k| h[k] = Set.new }
    versions.each do |v|
      next if v.event != "update" || v.object_changes.blank?
      changes = v.changeset rescue {}
      changes.each do |col, (old_v, new_v)|
        next unless fk_columns.include?(col)
        ids_by_column[col] << old_v.to_i if old_v.present?
        ids_by_column[col] << new_v.to_i if new_v.present?
      end
    end

    ids_by_column.each_with_object({}) do |(col, ids), index|
      next if ids.empty?
      resolver = FK_RESOLVERS[col]
      resolved = resolver.call(ids.to_a) rescue {}
      index[col] = resolved
    end
  end

  # Renderiza un valor crudo aplicando FK resolution si la columna es
  # un FK conocido. Fallback: devuelve audit_value(raw_value).
  def audit_resolved_value(column, raw_value, fk_index = {})
    return "—"      if raw_value.nil?
    return "(vacío)" if raw_value == ""

    if (col_index = fk_index[column.to_s])
      label = col_index[raw_value.to_i]
      return label.presence || "(eliminado ##{raw_value})"
    end

    case raw_value
    when true  then "Sí"
    when false then "No"
    when Date, DateTime, Time, ActiveSupport::TimeWithZone
      raw_value.strftime("%d %b %Y, %-I:%M %p")
    else raw_value.to_s.truncate(60)
    end
  end

  # ¿La version cambia el estado? Para destacar visualmente en timeline.
  def audit_changes_estado?(version)
    return false if version.event != "update" || version.object_changes.blank?
    (version.changeset rescue {}).key?("estado")
  end

  # Cambios filtrados (sin ruido) listos para iterar como pares
  # [column, [old, new]]. Excluye updated_at/created_at y opcionalmente
  # estado (cuando lo manejamos como evento principal aparte).
  def audit_clean_changes(version, exclude: [])
    return [] if version.event != "update" || version.object_changes.blank?
    changes = (version.changeset rescue {})
    changes = changes.except(*AUDIT_NOISY_COLUMNS, *exclude.map(&:to_s))
    changes.to_a
  end
end
