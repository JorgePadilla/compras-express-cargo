# PR-F1.4 · Fase 15. ¿Puede facturar cada sucursal hoy, y cuánto le queda?
#
# Lo calcula la gema (`Invoicehn::Issuance#health`, lo mismo que el
# `invoicehn check` de la línea de comandos) con los adaptadores de Postgres;
# esto le agrega lo que la pantalla de «Facturación SAR» necesita decidir:
#
# - **rojo**: no puede emitir. Sin autorización vigente que cubra el número que
#   sigue, o con el emisor incompleto (Art. 10 num. 1). Sin esto la primera
#   noticia es la factura que no sale con el cliente adelante.
# - **ámbar**: puede, pero se acaba. A 30 días o menos de la fecha límite, o
#   con el 10 % del rango o menos (nunca menos de 100 números) — salvo que el
#   CAI siguiente ya esté cargado a continuación.
# - **verde**: el resto.
#
# Además: los CAI vencidos con números sin usar (Art. 42: se informan a la SAR
# dentro de los primeros 10 días hábiles del mes siguiente) y si la
# autorización que se está usando es la ficticia de staging.
module Fiscal
  class Salud
    DIAS_DE_AVISO = 30
    PORCION_DE_AVISO = 0.10
    MINIMO_DE_AVISO = 100

    Fila = Data.define(:punto, :tipo, :estado, :siguiente, :quedan, :dias, :autorizacion,
                       :faltan_del_emisor, :vencidas_con_sobrantes, :motivos) do
      def rojo? = estado == :rojo
      def ambar? = estado == :ambar
      def ficticia? = autorizacion&.ficticia? || false
      def tipo_nombre = Fiscal::TIPOS_DE_DOCUMENTO.fetch(tipo)

      # Lo que dice la pastilla roja.
      def no_puede
        { "01" => "Esta sucursal no puede facturar",
          "06" => "No puede emitir notas de crédito",
          "07" => "No puede emitir notas de débito" }.fetch(tipo)
      end
    end

    # Una fila por punto activo y tipo: facturas siempre; notas, si el punto
    # ya tiene algo cargado de ese tipo.
    def self.de_todos(al: Fiscal.hoy)
      PuntoDeEmision.activos.includes(:sucursal).order(:establecimiento, :punto).flat_map do |punto|
        tipos_de(punto).map { |tipo| new(punto, tipo, al: al).fila }
      end
    end

    def self.tipos_de(punto)
      cargados = AutorizacionSar.where(punto_de_emision: punto).distinct.pluck(:tipo_documento) +
                 CorrelativoFiscal.where(punto_de_emision: punto).pluck(:tipo_documento)
      ([ "01" ] + cargados).uniq.sort
    end

    def initialize(punto, tipo, al: Fiscal.hoy)
      @punto = punto
      @tipo = tipo
      @al = al
    end

    def fila
      salud = Fiscal.issuance(punto: @punto).health(identifier: @punto.identificador(@tipo), on: @al)
      activa = salud[:active_authorization]
      autorizacion = activa && AutorizacionSar.find_by(punto_de_emision: @punto, tipo_documento: @tipo,
                                                       cai: activa.cai, rango_inicio: activa.range_start.sequence)
      faltan = faltan_del_emisor(salud)
      motivos = motivos_rojos(salud, faltan)
      motivos = motivos_ambar(salud, activa) if motivos.empty?

      Fila.new(punto: @punto, tipo: @tipo, estado: estado(salud, faltan, motivos),
               siguiente: salud[:next_correlative].to_s, quedan: salud[:remaining], dias: salud[:days_remaining],
               autorizacion: autorizacion, faltan_del_emisor: faltan,
               vencidas_con_sobrantes: vencidas_con_sobrantes, motivos: motivos)
    end

    private

    # QA de PR-F1.4 · Art. 42, contado con los documentos y no con el contador.
    # `lapsed_with_unused` de la gema compara el correlativo con el fin del
    # rango, y cargar el CAI siguiente sube el correlativo a su inicio menos uno
    # (`alinear_si_hace_falta`): el aviso se borraba justo al cargar el
    # reemplazo, que es cuando hay que informar. Los anulados cuentan: gastaron
    # su número.
    def vencidas_con_sobrantes
      AutorizacionSar.usables.del(@punto, @tipo).where(fecha_limite_emision: ...@al).order(:rango_inicio)
                     .select { |a| documentos_en_rango(a) < a.capacidad }.map(&:to_invoicehn)
    end

    # El número es `EEE-PPP-TT-NNNNNNNN`, de ancho fijo: el orden del texto es
    # el de los números.
    def documentos_en_rango(autorizacion)
      DocumentoFiscal.where(punto_de_emision: @punto, tipo_documento: @tipo,
                            numero: autorizacion.numero(autorizacion.rango_inicio)..autorizacion.numero(autorizacion.rango_fin))
                     .count
    end

    def faltan_del_emisor(salud)
      return [ "RTN de la empresa (14 dígitos)" ] unless salud[:issuer_configured]

      salud[:issuer_missing]
    end

    def motivos_rojos(salud, faltan)
      motivos = []
      if salud[:active_authorization].nil?
        motivos << (salud[:authorizations].zero? ? "No tiene autorizaciones cargadas" :
                      "Ninguna autorización vigente cubre el #{salud[:next_correlative]}")
        posterior = vigente_posterior(salud)
        if posterior
          motivos << "El CAI #{posterior.cai} empieza en el #{posterior.rango_inicio}: el correlativo no salta solo hasta ahí"
        end
      end
      motivos << "Faltan datos del emisor (Art. 10)" if faltan.any?
      motivos
    end

    def motivos_ambar(salud, activa)
      motivos = []
      dias = salud[:days_remaining]
      # El día de la fecha límite todavía se emite (Art. 62), y es el último.
      if dias && dias <= DIAS_DE_AVISO
        motivos << (dias.zero? ? "Vence hoy" : "Vence en #{dias} #{dias == 1 ? 'día' : 'días'}")
      end
      if salud[:remaining] <= umbral(activa) && !siguiente_cargada?(activa)
        motivos << "Quedan #{salud[:remaining]} números"
      end
      motivos
    end

    def estado(salud, faltan, motivos)
      return :rojo if salud[:active_authorization].nil? || faltan.any?

      motivos.any? ? :ambar : :verde
    end

    def umbral(activa)
      [ (activa.capacity * PORCION_DE_AVISO).ceil, MINIMO_DE_AVISO ].max
    end

    # QA de PR-F1.4 · El CAI vencido con números sin usar y el siguiente ya
    # cargado a continuación: el correlativo se queda en el vencido (solo se
    # alinea al crear o corregir un CAI) y la sucursal no factura aunque tenga
    # un CAI vigente. Que el motivo lo diga, en vez de parecer que falta un CAI.
    def vigente_posterior(salud)
      AutorizacionSar.usables.del(@punto, @tipo)
                     .where(fecha_limite_emision: @al.., rango_inicio: (salud[:next_correlative].sequence + 1)..)
                     .order(:rango_inicio).first
    end

    # Un CAI vigente que arranca justo donde termina el actual: los números no
    # se acaban, sigue en ese.
    def siguiente_cargada?(activa)
      AutorizacionSar.usables.del(@punto, @tipo)
                     .where(rango_inicio: activa.range_end.sequence + 1)
                     .where(fecha_limite_emision: @al..)
                     .exists?
    end
  end
end
