# PR-P.8 · Para los tests que necesitan **dos conexiones de verdad** —dos F9
# a la vez—, y por eso corren sin la transacción de test.
#
# Sin transacción nada se deshace solo, y lo que queda le cambia el mundo al
# test que sigue en el mismo worker: los Warehouse Receipts que acuña cada
# paquete nuevo rompían `WarehouseReceiptTest#recientes`, y el contador de
# números de recepción seguiría contando donde los demás esperan arrancar de
# cero. Las tablas con fixtures se recargan antes de cada test; esto borra lo
# de las otras.
module SinTransaccionDeTest
  extend ActiveSupport::Concern

  included do
    self.use_transactional_tests = false
  end

  # Todo lo que cuelga de estos paquetes y de estas tandas, y los paquetes.
  def borrar_lo_creado(paquetes, sesiones)
    ids = paquetes.map(&:id)
    pfs = PreFactura.joins(:pre_factura_items).where(pre_factura_items: { paquete_id: ids }).distinct.pluck(:id)
    items = PreFacturaItem.where(pre_factura_id: pfs).pluck(:id)
    bultos = Bulto.where(sesion: sesiones).pluck(:id)
    wrs = Paquete.where(id: ids).where.not(warehouse_receipt_id: nil).pluck(:warehouse_receipt_id)

    Paquete.where(id: ids).update_all(pre_factura_id: nil, warehouse_receipt_id: nil)
    PreFacturaItem.where(id: items).delete_all
    PreFactura.where(id: pfs).delete_all
    Bulto.where(id: bultos).delete_all
    Paquete.where(id: ids).delete_all
    WarehouseReceipt.where(id: wrs).delete_all
    # Sin fixtures: antes de este test estaba vacío en este worker.
    NumeroRecepcionCounter.delete_all
    PaperTrail::Version.where(item_type: "Paquete", item_id: ids)
                       .or(PaperTrail::Version.where(item_type: "Bulto", item_id: bultos))
                       .or(PaperTrail::Version.where(item_type: "PreFactura", item_id: pfs))
                       .or(PaperTrail::Version.where(item_type: "PreFacturaItem", item_id: items))
                       .delete_all
  end
end
