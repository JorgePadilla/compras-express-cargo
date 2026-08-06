# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end

# Spanish-language model names whose default pluralization breaks Rails helpers.
# English inflector turns "venta" into "ventum" (Latin-style) and similar quirks,
# which makes form_with model: @venta generate ventum_path. Declare irregular pairs.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "venta", "ventas"
  # PreAlerta: sin esta regla `pre_alerta`.singularize → "pre_alertum"
  # (regla Latin -a → -um). Causa que polymorphic_path(@pre_alerta)
  # busque `pre_alertum_path` que no existe.
  inflect.irregular "pre_alerta", "pre_alertas"
  inflect.irregular "nota_debito",      "notas_debito"
  inflect.irregular "nota_credito",     "notas_credito"
  inflect.irregular "nota_debito_item", "nota_debito_items"
  inflect.irregular "nota_credito_item", "nota_credito_items"
  inflect.irregular "cotizacion", "cotizaciones"
  inflect.irregular "cotizacion_item", "cotizacion_items"
  inflect.irregular "financiamiento", "financiamientos"
  inflect.irregular "financiamiento_cuota", "financiamiento_cuotas"
  inflect.irregular "entrega", "entregas"
  inflect.irregular "apertura_caja", "aperturas_caja"
  inflect.irregular "ingreso_caja", "ingresos_caja"
  inflect.irregular "egreso_caja", "egresos_caja"
  inflect.irregular "sucursal", "sucursales"
  inflect.irregular "proveedor", "proveedores"
  inflect.irregular "tarifa_recolecta", "tarifas_recolecta"
  inflect.irregular "servicio_extra",   "servicios_extra"
  inflect.irregular "motivo_retencion", "motivos_retencion"
  inflect.irregular "paquete_motivo_retencion", "paquete_motivos_retencion"
  inflect.irregular "plantilla_nota_cliente", "plantillas_notas_cliente"
  # PR-13.d: sin esto `has_many :autorizaciones` busca la clase `Autorizacione`.
  inflect.irregular "autorizacion", "autorizaciones"
end
