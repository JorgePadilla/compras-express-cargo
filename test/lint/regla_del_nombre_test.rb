require "test_helper"

# Que la regla de los tres ítems valga en TODA pantalla donde se teclea un nombre.
#
# Nació torcida: `PR-C7.33` la puso en `/clientes` y se olvidó de `/registro`, que
# es la pantalla gemela y encima la de afuera —pública, sin autenticar, linkeada
# desde el login—. Ahí un "Jorge Padilla" pasaba tranquilo, que es justo lo que
# Yusef quería evitar: *"imaginate cuántos Jorge Padilla hay"*.
#
# Es el bug recurrente de este repo —admin y portal tienen vistas gemelas y el
# arreglo llega a una— y por eso va lint y no solo un test funcional: los tests
# prueban las pantallas que hoy existen, esto avisa cuando aparece **una nueva**.
#
# La regla se enciende con `exigir_nombre_completo`, que es una bandera de
# instancia a propósito: los 9.000 clientes del sistema viejo vienen con dos
# palabras, y el importador que Jorge tiene pendiente no puede trabarse con ellos.
# Por eso el lint no exige la validación en el modelo, sino **la bandera en quien
# recibe params**.
class ReglaDelNombreTest < ActiveSupport::TestCase
  BANDERA = "exigir_nombre_completo".freeze

  # Las pantallas donde alguien teclea el nombre de un cliente.
  TECLEAN_UN_NOMBRE = %w[
    app/controllers/clientes_controller.rb
    app/controllers/registrations_controller.rb
  ].freeze

  test "las dos pantallas que teclean un nombre exigen los tres items" do
    sin_regla = TECLEAN_UN_NOMBRE.reject { |archivo| leer(archivo).include?(BANDERA) }

    assert_empty sin_regla, <<~MSG
      Estas pantallas crean o editan clientes sin encender la regla del nombre.

      Poné `@cliente.exigir_nombre_completo = true` antes de guardar.
    MSG
  end

  # El que de verdad traba el trinquete: encuentra la pantalla **nueva**.
  test "no aparecio otro lugar que construya un Cliente con params" do
    sospechosos = Dir[Rails.root.join("app/controllers/**/*.rb"),
                      Rails.root.join("app/services/**/*.rb")].filter_map do |ruta|
      src = File.read(ruta)
      relativa = Pathname.new(ruta).relative_path_from(Rails.root).to_s

      next if TECLEAN_UN_NOMBRE.include?(relativa)
      # `Cliente.new` sin argumentos es el objeto vacío para pintar un formulario;
      # no guarda nada y no tiene nombre que validar.
      #
      # El lookbehind es lo que evita que `PlantillaNotaCliente.new(params)` —que
      # termina en "Cliente" y no tiene nada que ver— cuente como falso positivo.
      next unless src.match?(/(?<![A-Za-z])Cliente\.(new|create!?)\s*\(\s*\S/)

      relativa
    end

    assert_empty sospechosos, <<~MSG
      Estos construyen un Cliente con datos y no están en la lista de pantallas
      que exigen el nombre completo.

      Si ahí alguien teclea el nombre, encendé `exigir_nombre_completo` y agregalo
      a TECLEAN_UN_NOMBRE. Si es un importador o un proceso interno, agregá acá
      el comentario de por qué queda exento.

      #{sospechosos.join("\n")}
    MSG
  end

  # Que la bandera siga siendo de instancia. Si alguien la vuelve un `validates`
  # a secas en el modelo, la migración de los 9.000 se cae de una y este lint es
  # el único lugar donde está escrito por qué.
  test "la regla sigue colgando de la bandera y no del modelo entero" do
    modelo = leer("app/models/cliente.rb")

    assert_match(/attr_accessor :#{BANDERA}/, modelo)
    assert_match(/validate :nombre_completo_lleva_tres_palabras,\s*\n\s*if:/, modelo,
                 "la validación tiene que seguir siendo condicional")
  end

  private

  def leer(ruta) = Rails.root.join(ruta).read
end
