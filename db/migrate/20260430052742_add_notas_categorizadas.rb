# PR-D2: notas categorizadas en paquetes + clientes (Yusef 2026-04-29):
#
# Paquete:
#   - notas_consolidacion: vienen de la pre-alerta consolidada (sync al
#     vincular). Visibles en etiquetar/pre-factura/sac.
#   - notas_retencion: razón por la que se retuvo (paquete dañado,
#     confirmar tipo de envío, etc.). OBLIGATORIA cuando estado=retenido.
#   - notas_al_cliente: notas que el equipo agrega para informar algo
#     al cliente. Etiquetar inicia, Pre-Factura/Caja/SAC adicionan.
#     Viaja en el email de notificación al recibir.
#   - (`notas_internas` ya existe — quedan igual: lectura interna entre
#      departamentos.)
#
# Cliente (notas permanentes mostradas en modal por área del usuario):
#   - `notas_miami` y `notas_honduras` ya existen (legacy).
#   - notas_caja: NUEVO — equipo de Caja en HND.
#   - notas_sac: NUEVO — equipo de SAC.
class AddNotasCategorizadas < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :notas_consolidacion, :text
    add_column :paquetes, :notas_retencion,     :text
    add_column :paquetes, :notas_al_cliente,    :text

    add_column :clientes, :notas_caja, :text
    add_column :clientes, :notas_sac,  :text
  end
end
