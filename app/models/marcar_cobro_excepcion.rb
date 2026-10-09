# C24-01 · Marcarle a **un paquete** que se cobra distinto, con PIN de supervisor.
#
# Yusef, 2026-09-05, contando el caso:
#
#   > "Tengo un cliente que me ha movido unos **generadores** […] Estos eran
#   >  **400 libras**. Pero **el volumen de esos es 150 libras**. Es lo que yo
#   >  […] voy a cobrar."
#
# O sea: cobrar **el menor** de los dos, que es al revés de la regla normal. Y el
# alcance lo acotó él, sin que se lo preguntaran:
#
#   > "El cliente **no es que toda la carga** ya se la cobro por peso, **sino que
#   >  exclusivamente esa**."
#
# Por eso no sirve `ClienteCobroVolumetrico` (`PR-C6.41`): es por cliente × tipo
# de envío, y prenderlo le cambiaría el cobro a toda la carga de ese cliente.
#
# ── Por qué existe si `Fase 13.d` ya deja cambiar el peso de una línea ────────
#
# Porque eso es **corregir** y él pidió **prevenir**: *"que lo tengamos previsto
# en prefactura"*. Con el camino de la línea, el cajero arma la pre-factura, le
# salen 400 libras y tiene que ir a buscar a un supervisor al mostrador — cada
# vez, para cada generador de ese cliente. Marcado en el paquete, la línea nace
# con las 150 y nadie tiene que acordarse.
#
# ── La forma: la de `QuitarCambioServicio`, con el registro de `Fase 13` ──────
#
# El repo tiene **dos** patrones de autorización con PIN y acá hacen falta las
# dos mitades:
#
#   · de `QuitarCambioServicio` —el análogo más cercano, que también es un flag
#     en un `Paquete`— salen los errores tipados y el guard de `ya_facturado?`;
#   · de `Autorizacion` (`Fase 13.d`) sale **el registro**: quién autorizó, qué
#     cambió y **por qué**, en la bitácora de `/autorizaciones`. Es lo que hace
#     que esto sirva como prueba, que es todo el punto de que Yusef pida control.
#
# El PIN **no se valida acá**: lo valida `Autorizacion` con sus propias reglas
# (`autorizante_habilitado` y `pin_correcto`). Duplicarlo sería tener dos formas
# de decir si un PIN sirve, y que se separen.
class MarcarCobroExcepcion
  # Quiénes pueden. Yusef: *"tiene que ser alguien de supervisor o para arriba"*,
  # y aparte excluyó a los agentes de SAC —*"no lo van a [manejar] a cualquier
  # servicio al cliente"*—.
  #
  # Se **deriva** de `ROLES_AUTORIZANTES` en vez de escribirse, igual que hace
  # `BajarCajasConPin`: es la lista que `RP-21` ya contestó para «quién lleva
  # PIN», y si mañana entra un quinto rol, entra acá solo.
  #
  # Miami queda afuera **a propósito**, y es la diferencia con `BajarCajasConPin`
  # —que sí lo suma—: allá el error nace en Miami (le ponen 2 cajas a lo que era
  # 1), acá la excepción es una decisión de cobro, y Miami hoy no la tiene.
  ROLES = User::ROLES_AUTORIZANTES

  class NoPermitido  < StandardError; end
  class SinMotivo    < StandardError; end
  class YaFacturado  < StandardError; end
  class PinInvalido  < StandardError; end

  def initialize(paquete:, excepcion:, supervisor:, pin:, motivo:, solicitado_por: nil)
    @paquete = paquete
    # `""` es «quitarle la excepción», que es cómo se deshace: el mismo acto, con
    # el mismo PIN y el mismo registro. Un camino aparte para desmarcar sería un
    # camino sin auditar.
    @excepcion = excepcion.presence
    @supervisor = supervisor
    @pin = pin.to_s
    @motivo = motivo.to_s
    @solicitado_por = solicitado_por || supervisor
  end

  # Devuelve la `Autorizacion` que quedó registrada.
  def call
    validar!

    autorizacion = nil

    Paquete.transaction do
      antes = @paquete.peso_cobrar

      # Se construye **antes** de tocar el paquete para que el PIN se valide
      # primero: si está mal, `save!` levanta y la transacción no dejó nada.
      autorizacion = Autorizacion.new(
        documento: @paquete,
        solicitado_por: @solicitado_por,
        autorizado_por: @supervisor,
        accion: "cobro_excepcion",
        concepto: @paquete.numero_recepcion_visible.presence || @paquete.tracking,
        motivo: @motivo,
        detalle: detalle,
        valor_anterior: antes,
        pin: @pin
      )
      autorizacion.save!

      @paquete.update!(cobro_excepcion: @excepcion)

      # El peso nuevo se registra **después** de aplicar, porque lo recalcula el
      # `before_save` del paquete: capturarlo antes guardaría el viejo. Es la
      # misma razón por la que `Autorizacion` hace su `snapshot_nuevo` al final.
      autorizacion.update_columns(valor_nuevo: @paquete.reload.peso_cobrar)
    end

    autorizacion
  end

  private

  def validar!
    raise NoPermitido, "Ese usuario no puede marcar excepciones de cobro." unless autorizado?
    raise SinMotivo, "El motivo es obligatorio: es el punto del registro." if @motivo.blank?
    raise ArgumentError, "Esa excepción de cobro no existe." unless excepcion_valida?
    raise YaFacturado, facturado_msg if ya_facturado?
  end

  # Solo el rol y el PIN cargado — que el PIN **sea el correcto** lo dice
  # `Autorizacion`, y su error sale por ahí.
  def autorizado?
    @supervisor.present? && @supervisor.activo? &&
      @supervisor.pin_digest.present? && @supervisor.tiene_rol?(ROLES)
  end

  def excepcion_valida?
    @excepcion.nil? || Paquete.cobro_excepcions.key?(@excepcion.to_s)
  end

  # Cambiarle el peso a un paquete que ya se facturó movería un documento
  # cerrado por atrás. Es el mismo guard de `QuitarCambioServicio`.
  def ya_facturado?
    @paquete.pre_factura&.facturado? || @paquete.venta_id.present?
  end

  def facturado_msg
    "#{@paquete.numero_recepcion_visible} ya está facturado: la excepción tendría " \
      "que ir por una nota de crédito, no por acá."
  end

  def detalle
    return "se le quitó la excepción" if @excepcion.nil?

    if @excepcion == "solo_peso"
      "cobra solo el peso real (#{@paquete.peso&.to_f} lb) " \
        "aunque el volumétrico sea #{@paquete.peso_volumetrico&.to_f} lb"
    else
      "cobra solo el volumétrico (#{@paquete.peso_volumetrico&.to_f} lb) " \
        "en vez del real (#{@paquete.peso&.to_f} lb)"
    end
  end
end
