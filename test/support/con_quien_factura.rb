# PR-F2.2a · Quien factura tiene que tener sucursal (Q5). Las fixtures de
# usuarios no la traen: esto se la pone, sin pasar por las validaciones del
# usuario, que no vienen al caso.
module ConQuienFactura
  def quien_factura(user = users(:cajero), sucursal: sucursales(:zeron_sps))
    user.update_columns(sucursal_id: sucursal&.id)
    user.reload
  end
end
