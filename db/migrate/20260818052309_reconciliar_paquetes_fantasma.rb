# Los paquetes fantasma que quedaron de antes de `PR-C7.20`.
#
# Un tracking pre-alertado que llegaba **dividido** dejaba huérfano el paquete
# que la pre-alerta había dejado esperando: sacaba una etiqueta de más —con `—`
# donde va el número de recepción— y contaba como pieza en el Warehouse Receipt,
# mientras la pre-alerta se quedaba congelada en «pre_alerta».
#
# `PR-C7.20` arregla el origen. Esto limpia lo que ya está grabado.
#
# La lógica vive en `Paquete.reconciliar_fantasmas!` y no acá: un método se
# puede testear —incluida la idempotencia, llamándolo dos veces— y un archivo de
# migración no.
#
# No toca nada de usuarios: ni `user_id` ni los `*_by_user_id`.
class ReconciliarPaquetesFantasma < ActiveRecord::Migration[8.0]
  def up
    resultado = Paquete.reconciliar_fantasmas!

    resultado[:reconciliados].each do |fantasma_id, caja_id|
      say "paquete #{fantasma_id} reconciliado con la caja #{caja_id}"
    end
    resultado[:saltados].each do |fantasma_id, motivo|
      say "paquete #{fantasma_id} SALTADO — #{motivo}"
    end
    say "#{resultado[:reconciliados].size} reconciliados, #{resultado[:saltados].size} saltados"
  end

  def down
    say "un fantasma borrado no se resucita: esta migración no se deshace"
  end
end
