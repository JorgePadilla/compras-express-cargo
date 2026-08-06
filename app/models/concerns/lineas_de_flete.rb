# PR-13.a: las líneas de flete de una nota de débito o de crédito, calculadas
# con el mismo motor que la pre-factura.
#
# Las dos las armaban con la cadena que PR-10.a vino a reemplazar:
#
#   cliente.categoria_precio&.precio_para(paquete.tipo_envio) ||
#     paquete.tipo_envio&.precio_libra
#
# Sin mínimos, sin escalones, y sin convertir a Lempiras — pero el documento
# se imprime en Lempiras. Es el mismo defecto de moneda que PR-10.a arregló en
# `build_from_paquetes` y PR-10.h en el preview de paquetes; estos dos eran los
# últimos que quedaban con la tabla vieja.
#
# No era teórico: la nota de débito se **auto-genera** en `PreFactura#facturar!`
# para todo paquete con `solicito_cambio_servicio`. Con los precios reales
# cargados (PR-10.g), un CER de 10 lb del cliente Regular se factura a
# L.1,118.30 y la nota le acreditaba L.35.00 — 32 veces menos.
module LineasDeFlete
  extend ActiveSupport::Concern

  class_methods do
    # Devuelve un hash de atributos por paquete, listo para `items.build`.
    #
    # `moneda` es la del documento: `CotizadorFlete` siempre calcula en
    # Lempiras, así que si la nota va en dólares hay que convertir.
    def lineas_de_flete(cliente:, paquete_ids:, moneda:, concepto_prefijo:)
      paquetes = cliente.paquetes.where(id: paquete_ids).includes(:tipo_envio, :sucursal)

      paquetes.map do |paquete|
        cotizacion = CotizadorFlete.call(
          tipo_envio: paquete.tipo_envio,
          cliente: cliente,
          # `proveedor` es a la vez columna string y nombre de asociación — se
          # busca por id para no depender de cuál gana el reader.
          proveedor: (Proveedor.find_by(id: paquete.proveedor_id) if paquete.proveedor_id),
          sucursal: paquete.sucursal,
          # `peso_cobrar` ya es el mayor entre el real y el volumétrico.
          peso: paquete.peso_cobrar
        )

        precio, subtotal = montos_en_moneda(cotizacion, moneda)

        {
          paquete: paquete,
          concepto: "#{concepto_prefijo} #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia}",
          peso_cobrar: cotizacion.peso_facturado,
          precio_libra: precio,
          subtotal: subtotal,
          # Le avisa al `before_validation` del item que no recalcule: cuando
          # aplicó el mínimo, el subtotal no sale de peso × precio.
          minimo_aplicado: cotizacion.aplico_minimo
        }
      end
    end

    private

    # Mismo criterio que `PreFactura.build_from_paquetes`: se convierte el
    # precio unitario y el subtotal se recalcula sobre él, para que en el
    # documento impreso cuadre peso × precio = subtotal. El mínimo es un total,
    # así que ese se convierte directo.
    def montos_en_moneda(cotizacion, moneda)
      precio = CurrencyAware.convertir(cotizacion.precio_libra,
                                       de: cotizacion.moneda, a: moneda,
                                       tasa: cotizacion.tasa)

      subtotal = if cotizacion.aplico_minimo
        CurrencyAware.convertir(cotizacion.subtotal, de: cotizacion.moneda, a: moneda,
                                tasa: cotizacion.tasa)
      else
        (cotizacion.peso_facturado * precio).round(2, BigDecimal::ROUND_HALF_UP)
      end

      [ precio, subtotal ]
    end
  end
end
