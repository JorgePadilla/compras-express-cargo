require "test_helper"

# Que las reglas del servicio no vuelvan a vivir en una sola pantalla.
#
# Jorge, 2026-08-20: *"el área de pre-alerta para los admin y clientes es muy
# diferente; faltan las reglas de servicio, que son importantísimas"*.
#
# El portal las respetaba las tres —reempaque, consolidación y un solo tracking—
# y admin ninguna, así que **admin podía grabar lo que el portal hace
# imposible**: una CKA marcada «con reempaque» y «consolidada».
class ReglasDeServicioCompartidasTest < ActiveSupport::TestCase
  PANTALLAS_DE_ADMIN = %w[
    app/views/pre_alertas/new.html.erb
    app/views/pre_alertas/edit.html.erb
  ].freeze

  test "ninguna pantalla de admin ofrece el reempaque como campo" do
    # Es un dato derivado del servicio. Una casilla es una segunda fuente de
    # verdad, y ya tuvimos dos que no coincidían: el badge «R» del listado leía
    # la columna mientras `tipo_envio_descripcion` leía la del servicio.
    con_casilla = PANTALLAS_DE_ADMIN.select do |vista|
      sin_comentarios(leer(vista)).match?(/check_box\s+:con_reempaque/)
    end

    assert_empty con_casilla, "vuelven a dejar elegir el reempaque:\n#{con_casilla.join("\n")}"
  end

  test "las dos usan el mismo partial de reglas" do
    sin_partial = PANTALLAS_DE_ADMIN.reject do |vista|
      leer(vista).include?('render "pre_alertas/reglas_del_servicio"')
    end

    assert_empty sin_partial
  end

  test "ningun controller acepta el reempaque por parametro" do
    # La puerta por la que vuelve la contradicción: el modelo lo deriva al crear
    # y al cambiar de servicio, así que una **edición** que lo mande sin tocar el
    # servicio plantaría una que la derivación ya no corrige.
    controllers = %w[
      app/controllers/pre_alertas_controller.rb
      app/controllers/cuenta/pre_alertas_controller.rb
    ]
    permiten = controllers.select { |a| leer(a).match?(/permit\([^)]*:con_reempaque/m) }

    assert_empty permiten, "aceptan un campo derivado por parámetro:\n#{permiten.join("\n")}"
  end

  test "el partial no decide las reglas: las lee del servicio" do
    # Si las escribiera a mano —"CKA no consolida"— agregar un servicio nuevo al
    # catálogo no cambiaría nada y nadie se enteraría.
    src = leer("app/views/pre_alertas/_reglas_del_servicio.html.erb")

    assert_includes src, "consolidable"
    assert_includes src, "max_paquetes_por_accion"
    TipoEnvio.pluck(:nombre).each do |nombre|
      assert_no_match(/>#{Regexp.escape(nombre)}</, src, "«#{nombre}» está escrito a mano")
    end
  end

  private

  def leer(ruta) = Rails.root.join(ruta).read

  # Los comentarios explican por qué el bloque es como es, y nombran justamente
  # lo que el lint busca. Mirarlos sería prohibir explicarse.
  def sin_comentarios(src) = src.gsub(/<%#.*?%>/m, "")
end
