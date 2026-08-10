require "test_helper"

# PR-C6.33: si una vista cablea un autocomplete, tiene que cablearle también
# el teclado.
#
# Los ocho autocompletes del sistema heredan de `BusquedaAutocomplete`, así que
# todos saben navegar con flechas y confirmar con Enter. Pero eso solo sirve si
# la vista les manda las teclas — y **tres vistas no lo hacían**:
#
#   · /pre_alertas/new
#   · el proveedor en el form de paquete
#   · el cambio de cliente en el form de paquete
#
# En esas tres el dropdown solo se podía usar con el mouse, aunque el JS
# estuviera completo. Es exactamente lo que Yusef pidió como "preseleccionar de
# los dropdown" (A3-10), y yo lo había leído como un cambio de UI cuando era un
# atributo faltante.
#
# Este test es la red para la próxima: el hueco no se ve mirando el JS ni
# mirando la vista por separado — solo mirando las dos juntas.
class AutocompleteTecladoTest < ActiveSupport::TestCase
  # `#search`/`#buscar` es lo que dispara la búsqueda; el que lo tenga cableado
  # es un autocomplete y necesita su teclado.
  DISPARA_BUSQUEDA = /input->([a-z-]+)#(?:search|buscar)/
  # Cada copia bautizó su handler distinto (`onKeydown`, `keydown`,
  # `clienteKeydown`…), así que no se exige un nombre: alcanza con que la vista
  # le mande el evento al controller.
  ATIENDE_TECLADO  = /keydown->%s#\w+/

  # Los dos de manifiesto NO son autocompletes: buscan paquetes para
  # **agregarlos** a un manifiesto, piden 3 caracteres y no llenan ningún campo
  # oculto — cada resultado es una acción, no una elección. Meterlos en
  # `BusquedaAutocomplete` sería el error opuesto al que este refactor vino a
  # arreglar: unificar cosas que solo se parecen por fuera.
  #
  # `tracking-duplicado` tampoco: no muestra una lista para elegir, solo avisa
  # que el tracking ya existe. No hay nada que navegar con flechas.
  NO_SON_AUTOCOMPLETE = %w[
    manifiesto-search manifiesto-autocomplete tracking-duplicado
  ].freeze

  test "toda vista con autocomplete le cablea el teclado" do
    huerfanos = []

    Dir.glob(Rails.root.join("app/views/**/*.html.erb")).each do |ruta|
      contenido = File.read(ruta)

      contenido.scan(DISPARA_BUSQUEDA).flatten.uniq.each do |identificador|
        next if NO_SON_AUTOCOMPLETE.include?(identificador)
        next if contenido.match?(Regexp.new(format(ATIENDE_TECLADO.source, Regexp.escape(identificador))))

        huerfanos << "#{ruta.sub(Rails.root.to_s + '/', '')} → #{identificador}"
      end
    end

    assert_empty huerfanos,
                 "estos autocompletes solo se pueden usar con el mouse — les falta " \
                 "`keydown->…#onKeydown` en el mismo `data-action`:\n  " +
                 huerfanos.join("\n  ")
  end
end
