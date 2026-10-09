# «Enviado según política» — el único lugar donde se escribe ese control.
#
# C18-06 · Yusef, 2026-08-26: *"es lo mismo que vos tenés como cuando retenés…
# necesitamos una listita igual como la otra: se le marca el checkbox y te
# despliega"*. Un paquete que llega sin identificación de servicio (sin
# pre-alerta, etiqueta incompleta, nombre a medias) se manda por la política de
# envío por defecto, y al cliente hay que explicarle por qué — unos 100 al mes.
#
# Es una copia deliberada de `RetenerMiamiComponent`, con las mismas reglas:
# componente y no partial (kwargs obligatorios, se pinta en tres pantallas con
# form builders distintos), `collection_check_boxes` para que el catálogo mande,
# el catálogo se **recibe** del controller, y nada lleva `required` porque vive
# adentro de un `<dialog>` cerrado (`#306`). Lo vigila
# `test/lint/enviado_por_politica_compartido_test.rb`.
#
# No es una retención: el paquete sigue su camino. Es una explicación.
class EnviadoPorPoliticaComponent < ViewComponent::Base
  def initialize(f:, motivos:)
    @f = f
    @motivos = motivos || []
  end

  attr_reader :f, :motivos

  def hay_motivos? = motivos.any?

  def activo? = f.object.enviado_por_politica?
end
