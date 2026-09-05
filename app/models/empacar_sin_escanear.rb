# C23-10 · Meterle al manifiesto, de un tirón, todo lo que le toca — sin pistola.
#
# Yusef, 2026-09-01, explicando de dónde sale:
#
#   > "Vienen ellos y preparan todas estas cajas, **no les da chance de
#   >  escanear** y le empacan al puro… meten todo."
#   > "Yo estoy empacando. **No lo voy a escanear.** Solo voy a empacar y lo voy
#   >  a enviar, porque **no hay chance**."
#
# Y la regla, que la dictó completa:
#
#   > "**Todos los paquetes que tienen el estatus** [recibido en Miami], **que
#   >  bajo el tipo de servicio** […] que ese fue el que seleccionó para este
#   >  [manifiesto], automáticamente […] **se va a enviar sin escanear**."
#   > "Y en el manifiesto, **automáticamente los halás**."
#
# El camino sin escaneo ya existía —`ManifiestosController#add_paquete`, uno por
# uno— y `FinalizarManifiesto` solo mueve los que **ya están** en el manifiesto.
# Lo que faltaba era exactamente este tirón.
#
# ── Las dos decisiones que el audio no traía (Jorge, 2026-09-02) ─────────────
#
# **1 · El estado no cambia.** Yusef dice *"ya todo fue empacado"*, pero está
# describiendo el acto, no el estatus: `empacado` en este sistema **implica
# caja**, y sin escaneo no hay caja. Lo escribe solo el camino con pistola y
# está documentado que nada puede exigirlo (`project_manifiesto_dos_caminos`).
# Así que acá los paquetes **se quedan en `recibido_miami`** y solo se atan al
# manifiesto — que es lo mismo que ya hacía `add_paquete`, y por eso sacarlos
# después con `remove_paquete` los deja donde estaban.
#
# **2 · Filtra por la sucursal de origen del manifiesto.** Él dijo «todos los
# del tipo de servicio». En Miami eso da igual porque hoy todo sale de ahí, pero
# sin el filtro un manifiesto se llevaría carga que está físicamente en otra
# sucursal.
#
# ── C23-14 · El interno, que quedó pendiente y ahora sí se puede ─────────────
#
# El estado que Yusef nombró —`recibido_miami`— **no existe en el interno**: su
# carga ya llegó a Honduras. `C23-10` lo dejó afuera diciendo que faltaba una
# regla de él; buscándola apareció que **lo que faltaba era un dato nuestro**.
#
# `paquetes.sucursal_actual` —*"ubicación física actual"*— la escribía **un solo
# lugar**: la recepción del propio interno. La carga que entra de Miami pasaba a
# `en_aduana` sin dejar dicho dónde aterrizó, así que preguntar *"qué hay parado
# en esta sucursal"* era imposible: para saber dónde estaba algo había que
# haberlo movido antes. `C23-14` lo cierra sellándola al recibir el oficial.
#
# Con eso el interno es **la misma regla, con las dos piezas que le tocan**:
#
#   | | oficial | interno |
#   |---|---|---|
#   | estado | `recibido_miami` | `disponible_entrega` |
#   | dónde está | recibido en la sucursal de origen | `sucursal_actual` = origen |
#
# `disponible_entrega` y no `en_aduana`: es el estado con el que la carga queda
# **lista en una sucursal**, y es el que ya usan los otros dos lugares que
# hablan del interno —`RecibirManifiesto#finalizar_interno!` cuenta ésos, y
# `NotificarLlegadaASucursal` avisa por ésos—. Lo que todavía está en aduana no
# se ha trabajado; mandarlo a otra sucursal sería moverlo antes de saber qué es.
class EmpacarSinEscanear
  Resultado = Struct.new(:agregados, keyword_init: true) do
    def ninguno? = agregados.zero?
  end

  def initialize(manifiesto, user: nil)
    @manifiesto = manifiesto
    @user = user
  end

  # ¿A quiénes barrería? Se calcula **antes** de apretar, para que el botón
  # diga cuántos son y el confirm no sea una sorpresa. Es la misma consulta que
  # corre `call`, así que el número del botón y lo que pasa no se pueden separar.
  def candidatos
    return Paquete.none unless aplica?

    base = Paquete.sin_manifiesto.by_tipos_envio(@manifiesto.tipo_envio_ids)

    if @manifiesto.tipo_interno?
      base.by_estado(ESTADO_INTERNO).where(sucursal_actual_id: @manifiesto.sucursal_origen_id)
    else
      base.by_estado(ESTADO).recibidos_en(@manifiesto.sucursal_origen_id)
    end
  end

  # Los dos tipos, mientras el manifiesto se pueda tocar. Sin sucursal de origen
  # no hay con qué filtrar y el tirón se llevaría carga de cualquier lado: en
  # ese caso no aplica, en vez de aplicar mal.
  def aplica?
    @manifiesto.creado? && @manifiesto.sucursal_origen_id.present?
  end

  # Cómo se llama lo que entra, para que la pantalla lo pueda decir sin repetir
  # la regla.
  def estado_buscado
    @manifiesto.tipo_interno? ? ESTADO_INTERNO : ESTADO
  end

  # `update!` uno por uno y **no `update_all`**. Es la lección que dejó escrita
  # `FinalizarManifiesto`: el `update_all` saltea la bitácora de paper_trail, y
  # en un módulo donde alguien va a preguntar «¿quién metió esto?» eso es justo
  # lo que se necesita. Acá el estado no cambia, pero el `manifiesto_id` sí, y
  # esa es la pregunta.
  def call
    agregados = 0

    Manifiesto.transaction do
      candidatos.find_each do |paquete|
        paquete.update!(manifiesto: @manifiesto)
        agregados += 1
      end

      @manifiesto.recalculate_totals! if agregados.positive?
    end

    Resultado.new(agregados: agregados)
  end

  # El estado que Yusef nombró, con su nombre. Vive acá y no suelto en el
  # controller para que la consulta de `candidatos` y la del contador del botón
  # no puedan decir cosas distintas.
  ESTADO = "recibido_miami".freeze

  # `C23-14` · El del interno: la carga que ya llegó y está lista en la sucursal.
  ESTADO_INTERNO = "disponible_entrega".freeze
end
