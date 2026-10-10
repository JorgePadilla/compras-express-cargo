# PR-F1.2 · Fase 15. El store de la gema `invoicehn`, en Postgres (D1 de
# FISCAL.md): el emisor, las autorizaciones y los documentos emitidos.
#
# ── Dónde quedan los documentos ──────────────────────────────────────────
#
# En `documentos_fiscales` (`DocumentoFiscal`), uno por número, con
# `Invoice#to_h` adentro. FISCAL.md los ponía en la Factura misma; no alcanza:
# la gema busca por número sin saber el tipo (la referencia de una nota es una
# factura), y borra el documento si el libro rechaza su asiento. Ver la
# migración `DocumentosFiscales`.
#
# ── El borrador ──────────────────────────────────────────────────────────
#
# El registro de negocio que se está emitiendo —la Factura de F2.2a, una nota—
# llega como `borrador:` y queda como `documentable` del documento. Es duck
# typing, para que F2.2a enchufe su modelo sin tocar esto:
#
#   borrador.estampar_documento_fiscal(invoice)  # opcional: copia número, CAI,
#                                                # rango, totales; NO guarda
#   borrador.retirar_documento_fiscal(invoice)   # opcional: lo contrario, si la
#                                                # emisión se deshace
#
# El store hace el `save!`. Un borrador, un documento: si ya tiene uno, el
# índice único de `documentable` lo frena.
module Fiscal
  class Store
    attr_reader :punto, :borrador

    def initialize(punto:, borrador: nil)
      @punto = punto
      @borrador = borrador
      # Lo que `delete_document` desenganchó, por número: la anulación que el
      # libro rechaza borra la forma ANULADA y vuelve a guardar la emitida, y
      # la emitida tiene que volver con su Factura.
      @retirados = {}
    end

    # --- emisor ----------------------------------------------------------

    def issuer
      Emisor.para(punto)
    end

    # --- autorizaciones ----------------------------------------------------

    def authorizations_for(identifier)
      punto_del_numero, tipo = Fiscal.punto_y_tipo(identifier)
      AutorizacionSar.usables.del(punto_del_numero, tipo).order(:rango_inicio).map(&:to_invoicehn)
    end

    # La de rango más bajo entre las vigentes que cubren `next_sequence`; la
    # misma regla que `Invoicehn::Storage::JsonStore`.
    def active_authorization(identifier, next_sequence: nil, on: Invoicehn.today)
      candidatas = authorizations_for(identifier).reject { |a| a.expired?(on) }
      if next_sequence
        numero = Invoicehn::Correlative.parse(format("%<id>s-%<n>08d", id: identifier, n: next_sequence))
        candidatas = candidatas.select { |a| a.covers?(numero) }
      end
      candidatas.min_by { |a| a.range_start.sequence }
    end

    # Pasa por `AutorizacionSar`, con sus reglas: sin pisarse, arriba de lo
    # emitido, y alinea el correlativo al crearse.
    def add_authorization(authorization)
      punto_del_numero, tipo = Fiscal.punto_y_tipo(authorization.identifier)
      AutorizacionSar.create!(punto_de_emision: punto_del_numero, tipo_documento: tipo, cai: authorization.cai,
                              rango_inicio: authorization.range_start.sequence,
                              rango_fin: authorization.range_end.sequence,
                              fecha_limite_emision: authorization.limit_date, cargada_por: Current.user)
      authorization
    rescue ActiveRecord::RecordInvalid => e
      raise Invoicehn::ValidationError, e.record.errors.full_messages.to_sentence
    end

    # --- documentos ------------------------------------------------------

    # Un documento emitido no se toca; solo su forma ANULADA lo reemplaza
    # (Art. 41). En un savepoint: si algo falla acá, la transacción de quien
    # emite sigue sana para que la gema pueda deshacer.
    def save_document(invoice)
      numero = invoice.correlative.to_s

      DocumentoFiscal.transaction(requires_new: true) do
        registro = DocumentoFiscal.lock.find_by(numero: numero)
        if registro.nil?
          crear(invoice, numero)
        elsif invoice.annulled?
          registro.update!(estado: invoice.status, documento: invoice.to_h)
          estampar(registro.documentable, invoice)
        else
          raise Invoicehn::ImmutableDocument,
                "el documento #{numero} ya está registrado y no puede modificarse (Art. 41)"
        end
      end
      invoice
    end

    # Solo la gema lo llama, cuando una emisión o una anulación se deshace.
    # Idempotente: borrar lo que no está no es un error.
    def delete_document(invoice)
      numero = invoice.correlative.to_s

      DocumentoFiscal.transaction(requires_new: true) do
        if (registro = DocumentoFiscal.find_by(numero: numero))
          documentable = registro.documentable
          registro.destroy!
          retirar(documentable, invoice)
          @retirados[numero] = documentable if documentable
        end
      end
      invoice
    end

    def find(correlative)
      registro = DocumentoFiscal.find_by(numero: correlative.to_s)
      raise Invoicehn::DocumentNotFound, "no existe el documento #{correlative}" unless registro

      registro.to_invoicehn
    end

    def exists?(correlative)
      DocumentoFiscal.exists?(numero: correlative.to_s)
    end

    # En orden cronológico, que es como el Art. 43 pide guardarlos.
    def all(from: nil, to: nil)
      registros = DocumentoFiscal.order(:fecha_emision, :numero)
      registros = registros.where(fecha_emision: from..) if from
      registros = registros.where(fecha_emision: ..to) if to
      registros.map(&:to_invoicehn)
    end

    private

    def crear(invoice, numero)
      punto_del_numero, tipo = Fiscal.punto_y_tipo(invoice.correlative.identifier)
      if punto_del_numero != punto
        raise Invoicehn::ValidationError,
              "#{numero} no es del punto #{punto.prefijo}: el emisor llevaría la dirección de otro establecimiento"
      end

      documentable = estampar(@retirados.delete(numero) || borrador, invoice)
      DocumentoFiscal.create!(numero: numero, punto_de_emision: punto_del_numero, tipo_documento: tipo,
                              fecha_emision: invoice.issue_date, estado: invoice.status,
                              cai: invoice.authorization.cai, documento: invoice.to_h,
                              documentable: documentable)
    end

    def estampar(registro, invoice)
      return nil if registro.nil?

      registro.estampar_documento_fiscal(invoice) if registro.respond_to?(:estampar_documento_fiscal)
      registro.save!
      registro
    end

    def retirar(registro, invoice)
      return if registro.nil? || !registro.respond_to?(:retirar_documento_fiscal)

      registro.retirar_documento_fiscal(invoice)
      registro.save!
    end
  end
end
