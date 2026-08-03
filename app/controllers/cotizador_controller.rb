# PR-10.b: endpoint JSON que alimenta el bloque "Valor a pagar" de
# /entrega_personal. Solo lectura, no persiste nada.
class CotizadorController < ApplicationController
  before_action :authorize_cotizador

  def show
    tipo_envio = TipoEnvio.find_by(id: params[:tipo_envio_id])
    return render(json: { ok: false, motivo: "sin_tipo_envio" }) if tipo_envio.nil?

    r = CotizadorFlete.call(
      tipo_envio: tipo_envio,
      cliente:    Cliente.find_by(id: params[:cliente_id]),
      proveedor:  Proveedor.find_by(id: params[:proveedor_id]),
      sucursal:   Sucursal.find_by(id: params[:sucursal_id]),
      peso: params[:peso], alto: params[:alto], largo: params[:largo], ancho: params[:ancho]
    )

    render json: {
      ok: true,
      tarifa_encontrada: r.tarifa_encontrada?,
      aplico_minimo: r.aplico_minimo,
      tasa: r.tasa.to_f,
      peso_cobrar: r.peso_facturado.to_f,
      vlbs: r.vlbs.to_f,
      precio_libra: par(r, r.precio_libra),
      subtotal: par(r, r.subtotal),
      impuesto: par(r, r.impuesto),
      total: par(r, r.total)
    }
  end

  private

  # Cada monto viaja en las dos monedas — "valor a pagar en dólares y
  # lempiras" (Yusef).
  def par(resultado, monto)
    { lps: monto.to_f, usd: resultado.en_usd(monto).to_f }
  end

  def authorize_cotizador
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura,
                 :supervisor_caja, :cajero)
  end
end
