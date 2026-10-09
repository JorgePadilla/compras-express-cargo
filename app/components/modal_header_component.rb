# PR-C29.12 · La franja de arriba de un modal, con **un tono por intención**.
#
# Jorge, 2026-10-08, mirando el modal «Su consolidado ya se midió»: *"the
# orange in here feels different from the other; I would like to somehow have
# a standard on the colors use"*. El naranja era `amber-700` sólido, que la
# paleta de `docs/07` no prevé para nada: amber es para notas, y en claro. Y
# no había regla: cada modal elegía su franja a mano — rojo, navy, ámbar, gris,
# teal claro, o ninguna.
#
# El tono no se elige por gusto sino por **lo que el modal le pide al
# operario**:
#
#   bloqueo  · algo está mal y no lo deja seguir      → rojo
#   atencion · tiene que decidir o mirar, no es error → oro (el warning de la paleta)
#   info     · informa, administra, pide un PIN       → navy
#   listo    · salió bien                             → teal
#   notas    · notas del cliente o del paquete        → ámbar claro, como la franja de notas
#
# `TONOS` es la única fuente: la tabla de `docs/07`, el lint
# (`tonos_de_modal_test`) y el JS que pinta la franja de `/etiquetar` en vivo
# (`data-etiquetar-tonos-value`) la leen de acá.
class ModalHeaderComponent < ViewComponent::Base
  # Lo que va a la derecha de la franja, si hace falta algo más que cerrar.
  renders_one :accion

  # La «×» de cerrar, una sola para toda la app: hereda la tinta de la franja,
  # así se lee igual sobre navy que sobre oro. Se pide con `cerrar:` y la
  # acción de Stimulus que cierra (`"click->modal#close"`).
  CERRAR = "p-1 rounded opacity-80 hover:opacity-100 hover:bg-black/10 foco-cec".freeze

  # Las franjas sólidas andan igual en claro y en oscuro; la de notas, que es
  # clara, lleva su par oscuro. Contraste de la tinta sobre el fondo:
  # blanco/red-700 6.47 · navy-dark/gold 9.39 · blanco/navy 14.43 ·
  # navy-dark/teal 6.69 · amber-900/amber-50 8.75 (oscuro: amber-200 11.11).
  TONOS = {
    bloqueo:  "bg-red-700 text-white",
    atencion: "bg-cec-gold text-cec-navy-dark",
    info:     "bg-cec-navy text-white",
    listo:    "bg-cec-teal text-cec-navy-dark",
    notas:    "bg-amber-50 text-amber-900 dark:bg-amber-900/20 dark:text-amber-200"
  }.freeze

  # `grande` es el de las pantallas de pistola (medición, etiquetar): se lee
  # parado, a un metro. `normal` es el de los formularios.
  TAMANOS = {
    grande: { franja: "px-8 py-5", titulo: "text-3xl", icono: "w-8 h-8" },
    normal: { franja: "px-6 py-4", titulo: "text-xl", icono: "w-6 h-6" },
    chico:  { franja: "px-5 py-3", titulo: "text-lg", icono: "w-5 h-5" }
  }.freeze

  def initialize(tono:, titulo: nil, kicker: nil, icono: nil, tamano: :normal,
                 titulo_tag: :p, titulo_id: nil, titulo_data: {}, kicker_data: {},
                 centrado: false, cerrar: nil, data: {}, class: nil)
    raise ArgumentError, "tono desconocido: #{tono.inspect} (son #{TONOS.keys.join(', ')})" unless TONOS.key?(tono)
    raise ArgumentError, "tamaño desconocido: #{tamano.inspect}" unless TAMANOS.key?(tamano)

    @tono = tono
    @titulo = titulo
    @kicker = kicker
    @icono = icono
    @tamano = TAMANOS.fetch(tamano)
    @titulo_tag = titulo_tag
    @titulo_id = titulo_id
    @titulo_data = titulo_data
    @kicker_data = kicker_data
    @centrado = centrado
    @cerrar = cerrar
    @data = data
    @clase_extra = binding.local_variable_get(:class)
  end

  def self.clases(tono) = TONOS.fetch(tono)

  private

  def clases_franja
    [ @tamano[:franja], TONOS.fetch(@tono), @clase_extra ].compact.join(" ")
  end

  # Centrado: el ícono va arriba del texto y no al costado.
  def clases_interior
    @centrado ? "flex flex-col items-center gap-2 text-center" : "flex items-start gap-3"
  end

  def titulo? = !@titulo.nil? || @titulo_data.present?
  def kicker? = !@kicker.nil? || @kicker_data.present?
end
