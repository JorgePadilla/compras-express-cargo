# Una sección de formulario: la tarjeta con su título, su bajada y su pie.
#
# ── Por qué es un componente y no clases copiadas ─────────────────────────
#
# Jorge, 2026-08-12: *"cuando entrás a pre-alerta cliente se mira diff a admin;
# admin requiere que lo acerquemos a cómo se mira el cliente"*.
#
# Las dos pantallas dibujaban la misma tarjeta con clases distintas —el portal
# `rounded-2xl` con degradado y título `text-2xl` navy; admin `rounded-xl`
# plano con título `text-sm` gris— y se separaron solas, sin que nadie decidiera
# separarlas. Restilar admin a mano las volvería a separar en tres meses: es el
# bug que más veces mordió este repo (la fila de paquete llegó a escribirse
# seis veces).
#
# Por eso el componente lo usan **las dos**. Que se vean parecidas deja de ser
# algo que hay que recordar y pasa a ser algo que no se puede evitar.
class FormSectionComponent < ViewComponent::Base
  renders_one :footer

  # `comoda` es la del portal: aire para leer, para una pantalla que se recorre
  # una vez. `compacta` mantiene el mismo lenguaje —degradado, radio, navy/gold,
  # separador— con menos alto, para las pantallas de trabajo donde hay siete
  # tarjetas seguidas y estirarlas obliga a scrollear todo el día.
  # `al_borde` es para la tarjeta que contiene una tabla: sin padding propio,
  # porque el encabezado y las filas ya traen el suyo y la tabla tiene que
  # llegar de borde a borde. Lleva `overflow-hidden` para que las esquinas
  # redondeadas recorten la primera y la última fila.
  DENSIDADES = {
    comoda:   { padding: "p-6 sm:p-8", sangria: "-mx-6 sm:-mx-8 px-6 sm:px-8",
                titulo: "text-xl sm:text-2xl", separacion: "mb-6" },
    compacta: { padding: "p-4 sm:p-5",  sangria: "-mx-4 sm:-mx-5 px-4 sm:px-5",
                titulo: "text-base",     separacion: "mb-4" },
    al_borde: { padding: "overflow-hidden", sangria: "px-4 sm:px-5",
                titulo: "text-base",     separacion: "mb-4" }
  }.freeze

  # El degradado se invierte en oscuro: de gris-800 a gris-900, para que la
  # tarjeta siga levantándose del fondo en vez de fundirse con él.
  TARJETA = <<~CSS.squish
    rounded-2xl shadow-sm border
    bg-gradient-to-br from-white to-gray-50 border-gray-100
    dark:from-gray-800 dark:to-gray-900 dark:border-gray-700
  CSS

  # Navy en claro, **gold en oscuro**. No es gusto: `text-cec-navy` sobre
  # gris-900 da 1.69:1 y fue el peor defecto de la auditoría de contraste;
  # `cec-gold` sobre el mismo fondo da 10.10:1. Es la misma regla que
  # `ButtonComponent` aplica en `outline_navy`.
  TITULO = "font-bold text-cec-navy dark:text-cec-gold"

  # `title` es opcional: la tarjeta de Paquetes no tiene título con bajada sino
  # una fila con el contador al costado, y se la dibuja ella.
  #
  # `attrs` va al elemento raíz porque varias de estas tarjetas **son** el
  # elemento de Stimulus —`data-controller="pre-alerta-editor"` vive en el div
  # de la tarjeta—. Envolverlas en otro div le cambiaría el alcance al
  # controller.
  def initialize(title: nil, subtitle: nil, densidad: :comoda,
                 alineacion_del_pie: "sm:justify-between", **attrs)
    @title = title
    @subtitle = subtitle
    @densidad = DENSIDADES.fetch(densidad.to_sym)
    @alineacion_del_pie = alineacion_del_pie
    @attrs = attrs
  end

  private

  def clases_de_tarjeta
    [ TARJETA, @densidad[:padding], @attrs[:class] ].compact.join(" ")
  end

  def atributos
    @attrs.except(:class).merge(class: clases_de_tarjeta)
  end

  def clases_del_titulo = "#{TITULO} #{@densidad[:titulo]} mb-2"

  # El separador va con la sangría negativa de su densidad para que llegue de
  # borde a borde de la tarjeta y no quede flotando adentro del padding.
  def clases_del_pie
    "mt-8 #{@densidad[:sangria]} pt-5 border-t border-gray-200 dark:border-gray-700 " \
      "flex flex-col-reverse sm:flex-row gap-3 #{@alineacion_del_pie}"
  end
end
