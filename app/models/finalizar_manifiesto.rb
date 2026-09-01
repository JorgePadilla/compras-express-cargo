# C21-06 · Finalizar el manifiesto: todo lo que va adentro pasa a ENVIADO.
#
# Del diagrama que dibujó Yusef: **«Finalizar e imprimir todos los paquetes con
# el tipo de envío nuestro seleccionado» → cambia estatus a ENVIADO.** Por eso
# los tipos de envío del manifiesto son obligatorios (`C21-03`): son los que
# deciden qué sale.
#
# **Y se acabó el `update_all`.** `Manifiesto#enviar!` movía los paquetes con un
# `update_all`, que saltea todos los callbacks. Costaba tres cosas concretas:
#
#   · **sin bitácora** — el salto a `enviado_honduras` no dejaba versión de
#     paper_trail, y en un módulo donde alguien va a preguntar «¿quién mandó
#     esto?» eso es justo lo que se necesita;
#   · **sin `fecha_enviado_by_user_id`** — el `ESTADO_FECHA_MAP` estampa la
#     fecha y el usuario al cambiar el estado, y con `update_all` no corre;
#   · **sin la guarda de tareas** — `no_advance_with_open_tareas` frena a un
#     paquete con tareas pendientes, y el manifiesto se la saltaba. La deuda
#     está anotada en `docs/05` (*"el manifiesto no lo mira (`update_all`)"*) y
#     `lib/procesos_pdf.rb` dice que se salda *"cuando se arme el de
#     manifiestos"* — o sea acá.
#
# El precio de saldarla: un paquete con tarea abierta **no pasa**.
#
# Y **traba el cierre entero** (Jorge, 2026-08-30, contestando la pregunta que
# quedó abierta al armar el módulo: *"bloquear cierre"*). Arrancó al revés —los
# trabados se listaban y el manifiesto cerraba sin ellos, copiando la forma de
# `A7-05`—, pero no es el mismo problema. En la recepción una caja que no
# aparece **ya está perdida** y no cerrar no la trae; acá el paquete está en la
# bodega, en la mano, y la tarea abierta es justo el aviso de que **algo le
# falta antes de subirse al camión**. Cerrar sin él lo deja fuera del manifiesto
# con el camión saliendo.
#
# Así que si hay uno solo trabado no se mueve nada: la transacción se revierte
# entera y la pantalla enumera cuáles y por qué.
class FinalizarManifiesto
  Resultado = Struct.new(:enviados, :trabados, keyword_init: true) do
    # Nada pasó y nada se movió: hay que resolver las tareas y volver a darle.
    def bloqueado?
      trabados.any?
    end
  end

  def initialize(manifiesto, user: nil)
    @manifiesto = manifiesto
    @user = user
  end

  def call
    enviados = []
    trabados = []

    Manifiesto.transaction do
      paquetes_a_enviar.each do |paquete|
        # La guarda de tareas abiertas **hay que preguntarla acá**, no confiar en
        # el modelo. `no_advance_with_open_tareas` compara índices de
        # `ESTADOS_ORDEN`, y `enviado_sucursal` no está ahí: es un desvío
        # (`ESTADOS_EXCEPCIONALES`), no un paso del pipeline. Así que en el
        # manifiesto **interno** el guard no dispara — `new_idx` sale nil y el
        # método se va sin mirar nada.
        #
        # Y la regla es la misma para los dos: el paquete está en la bodega, en
        # la mano, y la tarea abierta es justo el aviso de que le falta algo
        # antes de subirse al camión. Que el destino sea Tegucigalpa en vez de
        # Honduras no la cambia.
        if paquete.tareas_bloqueantes_pendientes?
          trabados << [ paquete, "tiene tareas pendientes" ]
        elsif paquete.update(**cambios_para(paquete))
          # `ESTADO_FECHA_MAP` estampa `fecha_<estado>_by_user_id` desde
          # `Current.user`, que en un request es quien apretó el botón. Fuera de
          # un request —consola, un job— queda en nil, y entonces volveríamos a
          # perder exactamente lo que perdía el `update_all`. Se rellena con el
          # usuario que se pasó, sin volver a correr callbacks.
          if @user && paquete.public_send(columna_de_usuario).nil?
            paquete.update_column(columna_de_usuario, @user.id)
          end
          enviados << paquete
        else
          trabados << [ paquete, paquete.errors.full_messages.to_sentence ]
        end
      end

      # Uno solo trabado revierte todo, incluidos los que sí habían pasado.
      if trabados.any?
        enviados = []
        raise ActiveRecord::Rollback
      end

      @manifiesto.update!(estado: "enviado", fecha_enviado: Time.current,
                          finalizado_por_id: @user&.id, finalizado_at: Time.current)
      @manifiesto.recalculate_totals!
    end

    Resultado.new(enviados: enviados, trabados: trabados)
  end

  private

  # `A7-09` · A dónde manda cada manifiesto.
  #
  # El **oficial** manda a `enviado_honduras`: la carga sale del extranjero y
  # cruza aduana. El **interno** manda a `enviado_sucursal`, que es el estado que
  # Yusef pidió como F7 y que existía en el enum **sin un solo escritor** desde
  # que se agregó.
  #
  # Y para qué lo quiere, con sus palabras: *"¿por qué va a servir ese status
  # nuevo? **Porque esto sirve de auditoría.** Qué paquete no escanearon o no
  # enviaron… se pueden ir a revisar el sistema y decir: ey, este sale pendiente,
  # hay que buscarlo"*, con la meta de *"que los errores se corrijan en 24
  # horas"*.
  #
  # **El destino sale del manifiesto, no del cliente.** `heredar_sucursal_destino`
  # cae a la sucursal donde el cliente retira, que es el caso normal; pero el
  # manifiesto sabe a dónde va el camión de verdad —puede ser una escala— y es el
  # que manda. Sin esto, un paquete de un cliente de SPS metido en el manifiesto
  # a Tegucigalpa se marcaría como que va a SPS.
  #
  # **No notifica nada**, y es a propósito: *"solo en sistema va a cambiar el
  # estatus"*. Al cliente se le avisa cuando la carga **llega**, no cuando sale
  # (`A7-08`, que es `PR-I4`).
  def cambios_para(_paquete)
    return { estado: "enviado_honduras" } unless @manifiesto.tipo_interno?

    { estado: "enviado_sucursal", sucursal_destino: @manifiesto.sucursal_entrega }
  end

  def columna_de_usuario
    @manifiesto.tipo_interno? ? :fecha_enviado_sucursal_by_user_id : :fecha_enviado_by_user_id
  end

  # *"Todos los paquetes con el tipo de envío nuestro seleccionado."* Los de
  # otro tipo que hayan entrado por «omitir» se quedan: el manifiesto no habla
  # de ellos.
  def paquetes_a_enviar
    @manifiesto.paquetes.where(tipo_envio_id: @manifiesto.tipo_envio_ids)
  end
end
