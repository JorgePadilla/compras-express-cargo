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
  inflect.irregular "nota_debito",      "notas_debito"
  inflect.irregular "nota_credito",     "notas_credito"
  inflect.irregular "nota_debito_item", "nota_debito_items"
  inflect.irregular "nota_credito_item", "nota_credito_items"
  inflect.irregular "cotizacion", "cotizaciones"
  inflect.irregular "cotizacion_item", "cotizacion_items"
  inflect.irregular "financiamiento", "financiamientos"
  inflect.irregular "financiamiento_cuota", "financiamiento_cuotas"
  inflect.irregular "entrega", "entregas"
  inflect.irregular "entrega_paquete", "entrega_paquetes"
  inflect.irregular "apertura_caja", "aperturas_caja"
  inflect.irregular "ingreso_caja", "ingresos_caja"
  inflect.irregular "egreso_caja", "egresos_caja"
end
