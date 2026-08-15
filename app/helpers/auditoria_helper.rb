# PR-C6.15: mostrar lo que `paper_trail` ya venía guardando.
#
# Yusef, revisando un paquete: "auditar quién... en este no, fíjate, pero en
# otros campos sí. No sé si es que se lo quitó o no había".
#
# Tenía razón a medias, y el doc lo diagnosticó al revés. **La captura no era
# el problema**: `has_paper_trail` está en 41 modelos. Lo que faltaba era
# *verlo*. Lo único con "quién" visible eran los cambios de estado, que llevan
# su propia columna `fecha_<estado>_by_user_id` — por eso unos campos sí y
# otros no.
module AuditoriaHelper
  # Campos que no aportan nada al leer un historial: los mantiene Rails o son
  # derivados de otro campo que sí se muestra.
  CAMPOS_RUIDO = %w[
    updated_at created_at
    peso_volumetrico peso_cobrar
    fecha_recibido_miami fecha_enviado fecha_llegada_hn fecha_disponible
    fecha_empacado fecha_aduana fecha_consolidando fecha_en_reparto
    fecha_entregado fecha_posible_entrega fecha_pre_alerta
    fecha_solicito_recolecta
  ].freeze

  ETIQUETAS = {
    "tracking" => "Tracking",
    "tracking_secundario" => "Tracking secundario",
    "cliente_id" => "Cliente",
    "tercero_id" => "Tercero",
    "tercero_nombre" => "Tercero (texto)",
    "descripcion" => "Descripción",
    "peso" => "Peso",
    "alto" => "Alto", "largo" => "Largo", "ancho" => "Ancho",
    "cantidad_paquetes" => "Cantidad de cajas",
    "numero_caja" => "N° de caja",
    "estado" => "Estado",
    "tipo_envio_id" => "Tipo de envío",
    "tipo_envio_anterior_id" => "Tipo de envío anterior",
    "sucursal_id" => "Retira en",
    "sucursal_recepcion_id" => "Recibido en",
    "numero_recepcion" => "N° de recepción",
    "proveedor" => "Proveedor",
    "expedido_por" => "Carrier",
    "remitente" => "Remitente",
    "notas_internas" => "Notas internas",
    "notas_al_cliente" => "Notas al cliente",
    "notas_retencion" => "Notas de retención",
    "retener_miami" => "Retener en Miami",
    "solicito_cambio_servicio" => "Cambio de servicio",
    "prepagado_miami" => "Prepagado en Miami",
    "prepagado_miami_metodo" => "Forma de pago en Miami",
    "driver" => "Driver"
  }.freeze

  def auditoria_etiqueta_campo(campo)
    ETIQUETAS[campo] || campo.humanize
  end

  # Los cambios que vale la pena leer de una versión. Devuelve
  # `[[etiqueta, antes, después], ...]`.
  def auditoria_cambios(version)
    version.changeset.except(*CAMPOS_RUIDO).map do |campo, (antes, despues)|
      [ auditoria_etiqueta_campo(campo), auditoria_valor(campo, antes), auditoria_valor(campo, despues) ]
    end
  end

  # Un id crudo no le dice nada a nadie. Se resuelve a nombre cuando el campo
  # es una FK conocida.
  def auditoria_valor(campo, valor)
    return "—" if valor.nil? || valor.to_s.strip.empty?

    case campo
    when "cliente_id", "tercero_id"           then Cliente.find_by(id: valor)&.nombre_completo || valor
    when "tipo_envio_id", "tipo_envio_anterior_id" then TipoEnvio.find_by(id: valor)&.nombre || valor
    when "sucursal_id", "sucursal_recepcion_id"    then Sucursal.find_by(id: valor)&.nombre || valor
    when "estado"                              then valor.to_s.humanize
    else
      if valor == true then "sí"
      elsif valor == false then "no"
      else valor.to_s.truncate(60)
      end
    end
  end

  # Quién hizo el cambio. `whodunnit` guarda el id del usuario
  # (`user_for_paper_trail` devuelve `Current.user&.id`).
  def auditoria_quien(version)
    return "Sistema" if version.whodunnit.blank?

    User.find_by(id: version.whodunnit)&.nombre || "Usuario ##{version.whodunnit}"
  end
end
