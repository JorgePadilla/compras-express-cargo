module BitacoraAutorizacionesHelper
  # El documento de una autorización, para la bitácora: el número y su link.
  #
  # La tabla se escribió para pre-facturas y notas, que tienen `numero`. Desde
  # C24-01 (excepción de cobro) y C28-13 (medir con faltantes) el documento
  # puede ser un **paquete**, que no tiene `numero`: `a.documento.numero`
  # reventaba la página entera. Un paquete se nombra como en su etiqueta —el
  # warehouse con su sufijo—.
  def documento_de_autorizacion(autorizacion)
    doc = autorizacion.documento
    return "—" if doc.nil?

    texto = doc.is_a?(Paquete) ? (etiqueta_codigo_barras(doc) || doc.tracking) : doc.numero
    link_to texto, doc, class: "font-mono text-cec-teal hover:text-cec-teal-dark"
  end
end
