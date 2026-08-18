# Cuando lo que llega a Miami ya estaba anunciado.
#
# Al crear una pre-alerta, `PreAlertaPaquete#crear_paquete_esperado` materializa
# un `Paquete` en estado `pre_alerta_estado` para que aparezca en `/paquetes`
# desde que el cliente lo anuncia. Cuando el bulto llega físicamente,
# `/etiquetar` **no crea otro**: encuentra el esperado y lo transiciona.
#
# Esto vivía suelto adentro de `create_single`, y `create_split` no lo tenía. Por
# eso un tracking pre-alertado que llegaba dividido dejaba al esperado huérfano
# con el mismo tracking que las cajas: salían **3 etiquetas para 2 cajas** —una
# con `—` donde va el número de recepción— y el Warehouse Receipt declaraba una
# pieza que nunca llegó. La pre-alerta tampoco avanzaba, porque
# `link_tracking!` filtra por `sin_vincular` y esa fila ya apuntaba al fantasma:
# quedaba invisible para su propio reparador.
#
# Vive en un concern porque son **dos caminos del mismo controller** y ya se
# separaron una vez. Copiar el bloque al otro lado arreglaba hoy y se volvía a
# separar mañana.
module ReconciliarPreAlerta
  extend ActiveSupport::Concern

  private

  # El paquete que la pre-alerta dejó esperando, si es que hay uno.
  #
  # PR-C6.21: por la escalera de `buscar_escaneado` y no por match exacto. La
  # pistola lee el código completo del carrier y el cliente pre-alertó solo la
  # cola —*"el tracking de USPS solo es desde donde dice 92"*—, así que el
  # exacto fallaba y el esperado quedaba huérfano mientras nacía uno nuevo al
  # lado.
  def paquete_esperado(escaneado)
    valor = escaneado.to_s.strip
    return nil if valor.blank?

    Paquete.where(estado: "pre_alerta_estado").buscar_escaneado(valor).first
  end

  # Qué tracking queda y qué se guarda como secundario.
  #
  # Cuando el match vino por sufijo, el que manda es **el del cliente**: es el
  # que él tiene en la mano y por el que va a preguntar. Lo que escupió la
  # pistola se guarda como secundario para que el mismo escaneo lo vuelva a
  # encontrar (`Paquete.buscar_escaneado` ya cubre las dos columnas).
  #
  # Devuelve `[tracking, secundario_o_nil]`. El `nil` significa "no toques el
  # secundario que ya venía en el formulario".
  def trackings_reconciliados(esperado, escaneado)
    valor = escaneado.to_s.strip
    return [ valor, nil ] if esperado.nil?

    del_cliente = esperado.tracking.to_s
    return [ del_cliente, nil ] if valor.casecmp?(del_cliente)

    [ del_cliente, valor ]
  end

  # El otro tracking del mismo bulto.
  #
  # Yusef, 2026-08-18: un paquete llega con **dos** códigos —el del carrier y el
  # del comercio— y el cliente pre-alerta uno, o el otro, o los dos. Si el
  # secundario también tenía su pre-alerta, ese esperado quedaba huérfano
  # exactamente igual que el fantasma de `PR-C7.20`, solo que por la otra
  # puerta: `paquete_esperado` mira **un** tracking.
  #
  #   > "Tiene que jalar esta información, compararlo, venir y unificarlos acá y
  #   >  eliminarlo de la pre-alerta. **No es vincularlo, eliminarlo**."
  #
  # Se llama después de guardar, con el paquete ya en la mano: su pre-alerta se
  # reapunta a él y el esperado sobrante se borra. Si el esperado del secundario
  # **es** el mismo que ya se reusó, `absorber!` se aparta solo.
  def absorber_esperado_del_secundario(paquete)
    return if paquete.nil? || paquete.tracking_secundario.blank?

    otro = paquete_esperado(paquete.tracking_secundario)
    paquete.absorber!(otro)
  end
end
