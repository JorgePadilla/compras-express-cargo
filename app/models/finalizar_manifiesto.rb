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
# El precio de saldarla: ahora un paquete con tarea abierta **no pasa**. Y no
# puede trabar al resto, así que se devuelve la lista y la pantalla la muestra —
# la misma forma que `A7-05` ya eligió para la recepción parcial: avisar con el
# faltante enumerado, no bloquear.
class FinalizarManifiesto
  Resultado = Struct.new(:enviados, :trabados, keyword_init: true)

  def initialize(manifiesto, user: nil)
    @manifiesto = manifiesto
    @user = user
  end

  def call
    enviados = []
    trabados = []

    Manifiesto.transaction do
      paquetes_a_enviar.each do |paquete|
        if paquete.update(estado: "enviado_honduras")
          # `ESTADO_FECHA_MAP` estampa `fecha_enviado_by_user_id` desde
          # `Current.user`, que en un request es quien apretó el botón. Fuera de
          # un request —consola, un job— queda en nil, y entonces volveríamos a
          # perder exactamente lo que perdía el `update_all`. Se rellena con el
          # usuario que se pasó, sin volver a correr callbacks.
          if @user && paquete.fecha_enviado_by_user_id.nil?
            paquete.update_column(:fecha_enviado_by_user_id, @user.id)
          end
          enviados << paquete
        else
          trabados << [ paquete, paquete.errors.full_messages.to_sentence ]
        end
      end

      @manifiesto.update!(estado: "enviado", fecha_enviado: Time.current,
                          finalizado_por_id: @user&.id, finalizado_at: Time.current)
      @manifiesto.recalculate_totals!
    end

    Resultado.new(enviados: enviados, trabados: trabados)
  end

  private

  # *"Todos los paquetes con el tipo de envío nuestro seleccionado."* Los de
  # otro tipo que hayan entrado por «omitir» se quedan: el manifiesto no habla
  # de ellos.
  def paquetes_a_enviar
    @manifiesto.paquetes.where(tipo_envio_id: @manifiesto.tipo_envio_ids)
  end
end
