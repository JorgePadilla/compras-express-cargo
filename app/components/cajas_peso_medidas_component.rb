# Peso, medidas, cajas y cálculo — el bloque que usan `/etiquetar` y
# `/entrega_personal` para capturar cuánto pesa y mide lo que entra.
#
# ── Por qué es un componente y no un partial con locals ───────────────────
#
# Porque el partial se rompió de la peor forma: en silencio y por un default.
#
# `shared/_peso_medidas_calc` resolvía sus defaults así:
#
#     <% modo_cajas = :plantilla unless defined?(modo_cajas) %>
#
# **Eso nunca asigna.** No es cosa de Rails: es Ruby. El parser define la
# variable local al *leer* la asignación, antes de evaluar la condición, así que
# `defined?(modo_cajas)` ya es truthy cuando se pregunta:
#
#     def f
#       y = :default unless defined?(y)
#       y            # => nil
#     end
#
# Con `modo_cajas` en `nil`, `/etiquetar` perdió el campo "Cant. Cajas" —y con él
# la única forma de dividir un paquete en varias cajas— el mismo día que
# `PR-C7.04` forkeó este bloque en dos. Jorge lo reportó dos días después:
# *"veo que en etiqueta no me deja agregar más cajas como en entrega personal,
# ¿qué pasó?"*.
#
# Un `initialize` de kwargs no se puede confundir con "definido pero nil". El bug
# desaparece por construcción, no por disciplina — que es la misma razón por la
# que existe `FormSectionComponent`.
#
# ── Una sola forma de cargar cajas ────────────────────────────────────────
#
# El repetidor, en las dos pantallas. `A7-20` lo decidió y su argumento nunca
# fue de Entrega Personal: es del operario.
#
#   > "Ellos agarran la caja, miden, y de ahí se van a la computadora.
#   >  **¿Cuáles cajas eran? ¿Cuáles fueron las que ya metí?**"
#   > "Es **paso por paso**. Es igual el manifiesto de Miami."
#
# Con una plantilla de N filas, el que vuelve de medir tiene que adivinar cuál le
# toca. Eso pasa en cualquier mostrador, no solo en el de Entrega Personal.
#
# **Con cero cajas agregadas nada cambia**: se llenan peso y medidas arriba y se
# guarda un solo bulto, como siempre.
class CajasPesoMedidasComponent < ViewComponent::Base
  DIMENSIONES = %i[alto largo ancho].freeze

  # `valor_a_pagar` es el panel de cobro estimado, y por default va **apagado**.
  # Es de Entrega Personal: ahí el cliente está enfrente preguntando cuánto es.
  # En `/etiquetar` se recibe carga de courier y el cobro se calcula después.
  #
  # `tipo_envio_id` lo necesita `calc-volumetrico` para saber si a este cliente
  # se le cobra solo el volumétrico en este servicio (`PR-C6.41`). En
  # `/etiquetar` es el de la sesión; en `/entrega_personal` lo reescribe el select.
  # `cajas_cargadas` son las que ya venían en el request. Normalmente ninguna:
  # solo hay cuando el guardado falló y el controller re-renderiza la pantalla.
  # Sin esto, **cualquier error de validación borraba todas las cajas medidas**
  # —las filas las pinta el JS y el re-render se las lleva— y el operario tenía
  # que volver a la bodega a pesarlas de nuevo.
  def initialize(f:, tipo_envio_id: nil, wrapper_class: "",
                 valor_a_pagar: false, cotizador_url: nil, cajas_cargadas: {})
    @f              = f
    @tipo_envio_id  = tipo_envio_id
    @wrapper_class  = wrapper_class
    @valor_a_pagar  = valor_a_pagar
    @cotizador_url  = cotizador_url
    @cajas_cargadas = cajas_cargadas || {}
  end

  attr_reader :f, :tipo_envio_id, :wrapper_class, :cotizador_url, :cajas_cargadas

  def valor_a_pagar? = @valor_a_pagar

  def controllers
    [ "calc-volumetrico", "cajas-repetidor", ("cotizador" if valor_a_pagar?) ].compact.join(" ")
  end

  # Los campos de captura avisan a los dos controllers en cada tecla. El del
  # cotizador solo se cablea cuando el panel existe.
  def accion_de_captura
    [ "input->calc-volumetrico#recalcular", ("input->cotizador#cotizar" if valor_a_pagar?) ]
      .compact.join(" ")
  end

  # Agregar o quitar una caja cambia el total del envío, y también el cobro.
  # `cajas-repetidor` emite el evento; los otros dos lo escuchan. Sin esto, el
  # panel se quedaba con el peso de la caja anterior — el bug que Jorge reportó.
  def accion_al_cambiar_cajas
    [ "cajas-repetidor:cambio->calc-volumetrico#recalcular",
     ("cajas-repetidor:cambio->cotizador#cotizar" if valor_a_pagar?) ].compact.join(" ")
  end

  # PR-C6.39: cuando el paquete viene de China, la forma que manda es el metro
  # cúbico. Las tres se siguen mostrando, pero la que cobra deja de verse igual
  # que las informativas.
  def cobra_por_metro_cubico?
    f.object.respond_to?(:cobra_por_metro_cubico?) && f.object.cobra_por_metro_cubico?
  end

  def clases_de_input(extra = nil)
    [
      "block w-full rounded-lg border-gray-300 dark:border-gray-600",
      "dark:bg-gray-700 dark:text-gray-100 shadow-sm text-sm",
      "focus:ring-cec-teal focus:border-cec-teal",
      extra
    ].compact.join(" ")
  end

  def clases_de_etiqueta
    "block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1"
  end
end
