# PR-C6.12: los servicios extra necesitan mínimo, como en el sistema viejo.
#
# Yusef, 2026-08-08, mostrando el CRUD de Roger: "precio mínimo a cobrar, lo
# tiene **obligado**".
#
# Y hace falta de verdad — el retornado de Miami *es* un mínimo:
#
#   > "Retornar a Miami dice 5 dólares, pero eso es como un precio mínimo que
#   >  cobramos, porque son 5 dólares MÁS el trámite más la llevada al correo."
#
# `Tarifa` ya tiene `minimo_monto` / `minimo_moneda`; `ServicioExtra` no tenía
# nada. La moneda del mínimo va aparte de la del precio a propósito: es el
# mismo criterio que en `Tarifa`, donde el flete se cotiza en dólares y el
# piso vive en Lempiras porque así lo pone la competencia.
class AgregarMinimoAServiciosExtra < ActiveRecord::Migration[8.0]
  def change
    add_column :servicios_extra, :minimo_monto,  :decimal, precision: 10, scale: 2
    add_column :servicios_extra, :minimo_moneda, :string
  end
end
