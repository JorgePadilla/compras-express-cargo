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

  Resultado = Struct.new(:tipo, :paquete, :candidatos, keyword_init: true) do
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

  # Un paquete ya elegido: el de la lista de resultados, o el que el modal de
  # «está en otro» va a mover.
  def clasificar(paquete)
    tipo =
      if paquete.manifiesto_id == @manifiesto.id then :en_este
      elsif paquete.manifiesto_id && !paquete.manifiesto.creado? then :en_otro_cerrado
      elsif !@manifiesto.acepta_tipo?(paquete) then :tipo_distinto
      elsif !@manifiesto.acepta_sucursal?(paquete) then :sucursal_distinta
      elsif paquete.estado.in?(FUERA_DE_CIRCULACION) then :fuera_de_circulacion
      elsif paquete.manifiesto_id then :en_otro
      else :ok
      end
    Resultado.new(tipo: tipo, paquete: paquete)
  end
end
