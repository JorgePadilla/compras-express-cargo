require "test_helper"

# PR: que las dos pantallas de Miami marquen el prepago igual.
#
# El prepago nació solo en `/entrega_personal`. Cuando Yusef pidió la forma de
# pago dijo *"esto es en la parte de Miami — etiquetar y entrega personal"*, y
# ahí se vio que `/etiquetar` **nunca lo tuvo**: una pantalla se quedó atrás sin
# que nadie lo decidiera.
#
# El flag se traduce a cinco columnas. Copiado en dos controllers, en un mes uno
# sella el método y el otro no, y el cajero de Honduras ve "PREPAGADO EN MIAMI"
# sin forma de pago en la mitad de los paquetes. Este lint es lo que lo impide.
class PrepagoCompartidoTest < ActiveSupport::TestCase
  PANTALLAS = {
    "app/views/etiquetar/index.html.erb" => "/etiquetar",
    "app/views/entrega_personal/new.html.erb" => "/entrega_personal"
  }.freeze

  CONTROLLERS = %w[
    app/controllers/etiquetar_controller.rb
    app/controllers/entrega_personal_controller.rb
  ].freeze

  test "las dos pantallas renderizan el mismo partial" do
    sin_partial = PANTALLAS.reject { |vista, _| leer(vista).include?('render "shared/prepago_miami"') }

    assert_empty sin_partial.values,
                 "estas pantallas no ofrecen el prepago desde el partial compartido"
  end

  test "ninguna pantalla escribe los radios a mano" do
    # Es como se separan: alguien copia el bloque en vez de usar el partial y a
    # partir de ahí las dos evolucionan por su lado.
    a_mano = PANTALLAS.keys.select do |vista|
      leer(vista).match?(/radio_button_tag\s+"paquete\[prepagado_miami/)
    end

    assert_empty a_mano
  end

  test "ningun controller sella el prepago por su cuenta" do
    # Las cinco columnas se asignan SOLO en `PrepagoMiami`. Si un controller las
    # toca directo, es que volvió a tener su propia versión.
    sueltos = CONTROLLERS.flat_map do |archivo|
      leer(archivo).each_line.filter_map do |linea|
        next unless linea.match?(/paquete\.prepagado_miami\w*\s*=/)
        "#{archivo}: #{linea.strip}"
      end
    end

    assert_empty sueltos, "asignan el prepago fuera del concern:\n#{sueltos.join("\n")}"
  end

  test "los dos controllers incluyen el concern" do
    sin_concern = CONTROLLERS.reject { |a| leer(a).include?("include PrepagoMiami") }

    assert_empty sin_concern
  end

  test "el partial ofrece los tres metodos, sin escribirlos a mano" do
    # Si el partial listara "Efectivo / Zelle / Tarjeta" en HTML, agregar un
    # cuarto método al modelo no lo mostraría — y nadie se enteraría hasta que
    # alguien preguntara por qué no aparece.
    partial = leer("app/views/shared/_prepago_miami.html.erb")

    assert_match(/METODOS_PREPAGO_MIAMI/, partial)
    Paquete::METODOS_PREPAGO_MIAMI.each do |metodo|
      assert_no_match(/value="#{metodo}"/, partial, "#{metodo} está escrito a mano en el partial")
    end
  end

  private

  def leer(ruta) = Rails.root.join(ruta).read
end
