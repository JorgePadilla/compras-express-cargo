# PR-C7.37: cuándo se le puso la clave al cliente.
#
# No es adorno de pantalla. `has_paper_trail` en `Cliente` saltea
# `password_digest` a propósito (es un hash y no aporta al log), así que **poner
# o cambiar la clave de un cliente no dejaba ninguna huella**: cualquiera con
# acceso a la ficha podía quedarse con la cuenta del cliente y la bitácora no lo
# registraba. Esta columna sí la registra, y de paso es lo que la ficha muestra
# para responder "¿ya puede entrar?".
class ClaveDelCliente < ActiveRecord::Migration[8.0]
  def change
    add_column :clientes, :clave_actualizada_at, :datetime
  end
end
