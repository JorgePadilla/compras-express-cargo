# PR-13.c: el PIN con el que un supervisor o jefe autoriza un cambio de precio
# en el mostrador.
#
# Yusef: "si lo quieren modificar, ellos tienen que pedir autorización — ahí es
# donde entra un jefe, un supervisor, y ahí es donde llega y **pone un código
# especial de él**".
#
# Va aparte de la contraseña a propósito: el supervisor NO inicia sesión. El
# cajero sigue logueado en su pantalla y el supervisor solo teclea cuatro
# dígitos parado ahí. Pedirle que cierre y abra sesión no es viable en un
# mostrador con el cliente enfrente.
#
# Se guarda con bcrypt (`has_secure_password :pin`) porque son 10 000
# combinaciones y es el único punto del sistema donde cuatro números habilitan
# mover plata.
#
# `pin_cambiado_at` en nil significa que todavía es el que le puso el admin. No
# bloquea autorizar —trabar el mostrador por eso sería peor que el riesgo— pero
# permite avisarle al supervisor y que el admin vea quién falta.
class AddPinAUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :pin_digest, :string
    add_column :users, :pin_cambiado_at, :datetime
  end
end
