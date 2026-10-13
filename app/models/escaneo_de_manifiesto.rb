# C28-04 · Qué pasa cuando la pistola lee un paquete en la pantalla del
# manifiesto, **y por qué**.
#
# Antes la pantalla buscaba solo entre los paquetes sin manifiesto, así que
# «ya está adentro» y «no existe» salían con el mismo mensaje: *«No se encontró
# ningún paquete libre»*. Yusef, el 2026-10-03: *"ya entendí, o sea **el
# mensaje está malo**"*. Y dijo qué tenía que decir en cada caso:
#
#   > "Este paquete ya fue escaneado y está en este manifiesto… pero si éste
#   >  está… ya fue escaneado y está en otro manifiesto, ahí ya levanta
#   >  sospecha… Ahí es un modal: ¿desea agregar este a este manifiesto y
#   >  retirarlo del otro?"
#   > "No es un error grave… El error es que diga que estás pagando CER y metas
#   >  un paquete CKA… ahí sí, porque genera gasto."
#
# C29-07 · Y un caso más: el paquete que va a **otra sucursal** que la del
# manifiesto. Va después del tipo porque el tipo es el que «genera gasto»: si
# fallan los dos, se dice primero ése.
#
# Esto **solo clasifica**. Agregar sigue siendo `add_paquete` y mover es
# `mover_paquete`: los dos escriben, y que haya una sola puerta de escritura
# por acción es lo que evita que el escaneo y el clic hagan cosas distintas.
class EscaneoDeManifiesto
  # Los estados con los que un paquete ya no viaja. Son los mismos que
  # `Paquete.sin_manifiesto` excluye de la lista para agregar.
  FUERA_DE_CIRCULACION = %w[anulado entregado retornado desechado].freeze

  # C31-02 · Los estados de un paquete que **ya llegó** a Honduras. Yusef, con
  # un paquete medido en San Pedro metido otra vez en un manifiesto de Miami:
  # *"¿Cómo me deja meter algo que ya lo recibí?"*
  ESTADOS_EN_HONDURAS = %w[en_aduana consolidando_honduras disponible_entrega
                           facturado en_reparto enviado_sucursal].freeze

  # `detalle` es el porqué de `ya_en_honduras`: qué lo delata.
  Resultado = Struct.new(:tipo, :paquete, :candidatos, :detalle, keyword_init: true) do
    def ok? = tipo == :ok
    def otro_manifiesto = paquete&.manifiesto
  end

  def initialize(manifiesto)
    @manifiesto = manifiesto
  end

  # Lo que leyó la pistola. El código `RMIA…-2` cae en esa caja y no en sus
  # hermanas (`Paquete.por_etiqueta_o_su_madre`), que es justo lo que se
  # quiere al escanear una etiqueta.
  def por_codigo(codigo)
    candidatos = Paquete.por_etiqueta_o_su_madre(codigo)
                        .where.not(estado: Paquete::NO_SON_CAJAS)
                        .includes(:cliente, :tipo_envio, :manifiesto).to_a
    return Resultado.new(tipo: :no_encontrado) if candidatos.empty?
    return clasificar(candidatos.first) if candidatos.one?

    # El tracking de un split, o el número madre sin sufijo, traen varias
    # cajas. Las que ya están acá no cuentan: si queda una sola, es ésa.
    libres = candidatos.reject { |p| p.manifiesto_id == @manifiesto.id }
    return clasificar(candidatos.first) if libres.empty?
    return clasificar(libres.first) if libres.one?

    Resultado.new(tipo: :varios, candidatos: libres)
  end

  # C30-06 · La otra dirección: lo que leyó la pistola en «Eliminar paquetes».
  # Solo cuenta lo que está **en este** manifiesto; el mismo resolvedor
  # (`por_etiqueta_o_su_madre`) hace que la etiqueta `RMIA…-2` saque esa caja
  # y no a sus hermanas.
  #
  #   ok          → hay uno solo acá: se saca (`remove_paquete`)
  #   no_se_saca  → está acá, pero ya tiene pre-factura o medición
  #                 (`Manifiesto#motivo_para_no_sacar`, PR-C30.14)
  #   varios      → el tracking de un split, o el número madre sin sufijo, con
  #                 varias cajas acá: no se adivina cuál no se fue
  #   no_esta_aca → existe, pero no está en este manifiesto
  #   no_encontrado
  def para_quitar(codigo)
    candidatos = Paquete.por_etiqueta_o_su_madre(codigo)
                        .where.not(estado: Paquete::NO_SON_CAJAS)
                        .includes(:manifiesto).to_a
    return Resultado.new(tipo: :no_encontrado) if candidatos.empty?

    aca = candidatos.select { |p| p.manifiesto_id == @manifiesto.id }
    return Resultado.new(tipo: :no_esta_aca, paquete: candidatos.first) if aca.empty?
    # PR-C30.14 · Se dice **antes** de intentar, adentro del modal: si no, el
    # `DELETE` fallaba después y la pistola sonaba a «sale» sin que saliera.
    if aca.one?
      tipo = @manifiesto.motivo_para_no_sacar(aca.first) ? :no_se_saca : :ok
      return Resultado.new(tipo: tipo, paquete: aca.first)
    end

    Resultado.new(tipo: :varios, candidatos: aca)
  end

  # Un paquete ya elegido: el de la lista de resultados, o el que el modal de
  # «está en otro» va a mover.
  #
  # C31-02 · `ya_en_honduras` va antes que el tipo y la sucursal: un paquete que
  # ya se recibió no vuelve a viajar desde Miami, sea del servicio que sea. Y
  # después de los dos de «está en un manifiesto», que lo dicen más preciso.
  def clasificar(paquete)
    detalle = nil
    tipo =
      if paquete.manifiesto_id == @manifiesto.id then :en_este
      elsif paquete.manifiesto_id && !paquete.manifiesto.creado? then :en_otro_cerrado
      elsif (detalle = por_que_ya_esta_en_honduras(paquete)) then :ya_en_honduras
      elsif !@manifiesto.acepta_tipo?(paquete) then :tipo_distinto
      elsif !@manifiesto.acepta_sucursal?(paquete) then :sucursal_distinta
      elsif paquete.estado.in?(FUERA_DE_CIRCULACION) then :fuera_de_circulacion
      elsif paquete.manifiesto_id then :en_otro
      else :ok
      end
    Resultado.new(tipo: tipo, paquete: paquete, detalle: detalle)
  end

  private

  # C31-02 · Qué dice que el paquete ya se recibió en Honduras, o nil. Lo de
  # `Manifiesto#motivo_para_no_sacar` mirado desde la puerta de entrada: lo que
  # ya está medido o en una pre-factura no sale de su manifiesto, así que
  # tampoco puede entrar a otro.
  #
  # **Solo en el oficial.** El interno lleva justamente lo que ya llegó —de una
  # sucursal de Honduras a otra—: ahí estar «disponible» es lo normal.
  # Lo que ya no viaja (entregado, anulado…) tiene su propio aviso.
  def por_que_ya_esta_en_honduras(paquete)
    return unless @manifiesto.tipo_oficial?
    return if paquete.estado.in?(FUERA_DE_CIRCULACION)

    if (pre_factura = @manifiesto.pre_factura_vigente_de(paquete))
      "está en la pre-factura #{pre_factura.numero}"
    elsif paquete.medicion_sesion.present? || paquete.medido_at.present?
      "ya se midió en San Pedro"
    elsif paquete.estado.in?(ESTADOS_EN_HONDURAS)
      "está «#{EstadoPaqueteHelper::ETIQUETAS.fetch(paquete.estado, paquete.estado.humanize).downcase}»"
    end
  end
end
