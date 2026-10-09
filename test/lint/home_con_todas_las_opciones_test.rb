require "test_helper"

# Toda opción de la barra lateral tiene su tarjeta en el Home (`/`), y con el
# **mismo ícono**.
#
# Jorge, 2026-10-08: *"let's make sure all the options in the left have an
# icon in the root /"*. Cuando se miró, al Home le faltaban ocho —Medición,
# Autorizaciones, Permisos por rol, Títulos de los roles, Catálogos del
# Manifiesto, Plantillas Descripción, Tasa de Cambio, Ajustes de Etiqueta— y
# cuatro tenían otro ícono que en la barra. Es el bug de siempre de este
# repo: dos listas a mano que se separan (`project_duplicacion_entre_pantallas`).
#
# Este lint compara las dos fuentes por **ruta**, no por nombre: el rótulo
# puede ser más corto en la tarjeta («Envío por Política»), la ruta no.
# Que cada rol vea las suyas lo cuida `dashboard_controller_test`.
class HomeConTodasLasOpcionesTest < ActiveSupport::TestCase
  BARRA = Rails.root.join("app/views/layouts/_sidebar_admin.html.erb")
  HOME  = Rails.root.join("app/controllers/dashboard_controller.rb")

  # `sidebar_link "Etiquetar", etiquetar_path, icon: "tag"` → { "etiquetar_path" => "tag" }
  def en_la_barra
    File.read(BARRA).scan(/sidebar_link\s+"[^"]+",\s*([a-z_]+_path)[^,]*,\s*icon:\s*"([^"]+)"/).to_h
  end

  # `card("Etiquetar", "…", "tag", etiquetar_path, :navy)` → { "etiquetar_path" => "tag" }
  def en_el_home
    File.read(HOME).scan(/card\(\s*"[^"]+",\s*(?:nil|"[^"]*"),\s*"([^"]+)",\s*([a-z_]+_path)/m)
        .to_h { |icono, ruta| [ ruta, icono ] }
  end

  test "las dos listas se leyeron" do
    assert_operator en_la_barra.size, :>, 30, "la barra salió con #{en_la_barra.size} opciones: el lint no la está leyendo"
    assert_operator en_el_home.size, :>, 30, "el Home salió con #{en_el_home.size} tarjetas: el lint no lo está leyendo"
  end

  test "toda opción de la barra tiene su tarjeta en el Home" do
    faltan = en_la_barra.keys - [ "root_path" ] - en_el_home.keys
    assert_empty faltan, "Estas opciones de la barra no tienen tarjeta en el Home: #{faltan.join(', ')}"
  end

  test "la tarjeta lleva el mismo ícono que la barra" do
    distintos = en_la_barra.filter_map do |ruta, icono|
      otro = en_el_home[ruta]
      "#{ruta}: barra «#{icono}», Home «#{otro}»" if otro && otro != icono
    end
    assert_empty distintos, "Una misma opción con dos íconos se lee como dos cosas:\n#{distintos.join("\n")}"
  end
end
