# PR-F1.2 · Fase 15. El correlativo de la gema `invoicehn`, en Postgres (D1 de
# FISCAL.md): `correlativos_fiscales`, una fila por punto de emisión y tipo.
#
# Lo que la gema le exige (`Invoicehn::TestSupport::SequenceContract`) es una
# sola propiedad: **el número avanza solo si el bloque termina**. Así una
# emisión que falla —el libro rechaza el asiento, la validación no pasa— no
# quema un número, que la SAR no acepta (Art. 10 num. 7 lit. d).
#
# `allocate` lo hace con un savepoint dentro de la transacción de quien llama:
#
#   1. `INSERT … ON CONFLICT DO NOTHING`: la fila existe aunque sea el primer
#      documento de ese punto y tipo.
#   2. `SELECT … FOR UPDATE`: el segundo que emite en el mismo punto y tipo
#      espera acá hasta que el primero confirme. Sin huecos y sin repetidos.
#   3. Le pasa `ultimo + 1` al bloque, y **recién después** escribe `ultimo`.
#
# Si el bloque tira, el savepoint se deshace —también el documento que haya
# guardado— y el contador queda donde estaba.
module Fiscal
  class Sequence
    def peek(identifier)
      correlativo(identifier, ultimo(identifier) + 1)
    end

    def issued_count(identifier)
      ultimo(identifier)
    end

    def allocate(identifier)
      punto, tipo = Fiscal.punto_y_tipo(identifier)

      CorrelativoFiscal.transaction(requires_new: true) do
        fila = bloquear(punto, tipo)
        siguiente = correlativo(identifier, fila.ultimo + 1)

        resultado = block_given? ? yield(siguiente) : siguiente

        fila.update!(ultimo: siguiente.sequence)
        resultado
      end
    end

    # La semántica de la gema: sube el contador a `rango_inicio - 1` si está
    # más abajo, para un rango que no arranca en 1. Acepta un
    # `Invoicehn::Authorization` o un `AutorizacionSar`. Devuelve el `ultimo`.
    def align_to(authorization)
      autorizacion = authorization.is_a?(AutorizacionSar) ? authorization.to_invoicehn : authorization
      punto, tipo = Fiscal.punto_y_tipo(autorizacion.identifier)
      piso = autorizacion.range_start.sequence - 1

      CorrelativoFiscal.transaction(requires_new: true) do
        fila = bloquear(punto, tipo)
        fila.update!(ultimo: piso) if fila.ultimo < piso
        fila.ultimo
      end
    end

    # Lo que corre al cargar un CAI (`AutorizacionSar` after_create). Alinea
    # **solo si el número que sigue no lo cubre otra autorización vigente**: el
    # CAI siguiente se pide antes de que se acabe el actual, y alinear ahí
    # saltearía lo que le queda al actual —números que la SAR autorizó y nunca
    # se usarían (Art. 42)—.
    def alinear_si_hace_falta(autorizacion)
      CorrelativoFiscal.transaction(requires_new: true) do
        fila = bloquear(autorizacion.punto_de_emision, autorizacion.tipo_documento)
        siguiente = fila.ultimo + 1
        cubierto = AutorizacionSar.usables
                                  .del(autorizacion.punto_de_emision, autorizacion.tipo_documento)
                                  .where.not(id: autorizacion.id)
                                  .where(rango_inicio: ..siguiente, rango_fin: siguiente..)
                                  .where(fecha_limite_emision: Fiscal.hoy..)
                                  .exists?
        piso = autorizacion.rango_inicio - 1
        fila.update!(ultimo: piso) if !cubierto && fila.ultimo < piso
        fila.ultimo
      end
    end

    # PR-F1.4 · El contador vuelto a calcular desde cero: lo emitido de verdad
    # (`documentos_fiscales`, donde la gema guarda todo lo que numera) y, si el
    # número que sigue no lo cubre ninguna autorización vigente, el inicio de la
    # próxima menos uno. Nunca baja de un documento emitido. Lo usa la
    # corrección del rango de un CAI sin usar, que puede mover el contador para
    # cualquiera de los dos lados.
    def recalcular(punto, tipo)
      CorrelativoFiscal.transaction(requires_new: true) do
        fila = bloquear(punto, tipo)
        emitido = self.class.ultimo_emitido(punto.id, tipo)
        vigentes = AutorizacionSar.usables.del(punto, tipo).where(fecha_limite_emision: Fiscal.hoy..)

        objetivo = emitido
        unless vigentes.where(rango_inicio: ..emitido + 1, rango_fin: emitido + 1..).exists?
          proximo = vigentes.where(rango_inicio: emitido + 1..).minimum(:rango_inicio)
          objetivo = proximo - 1 if proximo
        end
        fila.update!(ultimo: objetivo) if fila.ultimo != objetivo
        fila.ultimo
      end
    end

    # El número más alto con documento guardado, 0 si no hay ninguno.
    def self.ultimo_emitido(punto_id, tipo)
      numero = DocumentoFiscal.where(punto_de_emision_id: punto_id, tipo_documento: tipo).maximum(:numero)
      numero ? numero.split("-").last.to_i : 0
    end

    private

    def ultimo(identifier)
      punto, tipo = Fiscal.punto_y_tipo(identifier)
      CorrelativoFiscal.where(punto_de_emision: punto, tipo_documento: tipo).pick(:ultimo) || 0
    end

    def bloquear(punto, tipo)
      ahora = Time.current
      CorrelativoFiscal.insert_all(
        [ { punto_de_emision_id: punto.id, tipo_documento: tipo, ultimo: 0, created_at: ahora, updated_at: ahora } ],
        unique_by: :index_correlativos_fiscales_unicos
      )
      CorrelativoFiscal.lock("FOR UPDATE").find_by!(punto_de_emision: punto, tipo_documento: tipo)
    end

    def correlativo(identifier, secuencia)
      Invoicehn::Correlative.parse(format("%<id>s-%<n>08d", id: identifier, n: secuencia))
    end
  end
end
