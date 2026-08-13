class AddSucursalDestinoAPaquetes < ActiveRecord::Migration[8.0]
  # A7-09. Yusef pidió un estado propio para "va camino a una sucursal", y su
  # razón no es cosmética:
  #
  #   > "¿Por qué va a servir ese status nuevo? **Porque esto sirve de
  #   >  auditoría.** Qué paquete no escanearon o no enviaron… Se pueden ir a
  #   >  revisar el sistema y decir: ey, este sale pendiente, hay que buscarlo."
  #   > "A qué me refiero: que **los errores se corrijan en 24 horas**."
  #
  # El estado solo no alcanza: hay que saber a QUÉ sucursal va. `paquetes` ya
  # tiene cinco FKs a sucursales (retiro, recepción, actual, sub-localidad,
  # prepagado) y ninguna sirve — `sucursal` es dónde el cliente retira, que es
  # el destino final, no el tramo que se está despachando ahora.
  def change
    add_reference :paquetes, :sucursal_destino,
                  foreign_key: { to_table: :sucursales }, null: true, index: true
  end
end
