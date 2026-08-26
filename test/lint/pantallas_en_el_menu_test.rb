require "test_helper"

# Que no quede una pantalla que existe y a la que no se llega.
#
# PR-C7.40. Jorge, mirando el menú: *"veo que falta la parte de tareas"*,
# *"faltan los links del menú"*. Y tenía razón: `/tareas` no estaba en el sidebar
# ni en el dashboard. El repo ya tenía dos guardias en el otro sentido —que
# ninguna tarjeta apunte a `#`, y que el dashboard llegue a todos los catálogos—
# pero nada vigilaba **este**: una pantalla entera invisible.
#
# Una pantalla a la que solo se llega escribiendo la URL, en la práctica no
# existe para quien no la conoce.
class PantallasEnElMenuTest < ActiveSupport::TestCase
  # Rutas de índice que a propósito NO van al menú, con el porqué de cada una.
  # Sacar algo de acá es una decisión, no un descuido — que es justo lo que este
  # lint quiere forzar.
  EXENTAS = {
    "preview_view_components" => "previews de ViewComponent, herramienta de desarrollo",
    "categoria_precios"       => "PR-C7.12: se administran dentro de la Tabla de Servicios; Jorge: 'no le veo mucho valor'"
  }.freeze

  test "toda pantalla de indice se alcanza desde el menu" do
    nav = leer("app/views/layouts/_sidebar_admin.html.erb") +
          leer("app/controllers/dashboard_controller.rb")

    huerfanas = indices_de_admin.reject do |nombre, _|
      EXENTAS.key?(nombre) || nav.include?("#{nombre}_path")
    end

    assert_empty huerfanas.keys, <<~MSG
      Estas pantallas existen y no se llega a ellas desde el sidebar ni desde el
      dashboard. Escribiendo la URL a mano, nada más.

      Poneles un `sidebar_link` y una card, o agregalas a EXENTAS con el porqué.

      #{huerfanas.map { |n, ruta| "  #{n}_path (#{ruta})" }.join("\n")}
    MSG
  end

  # El otro lado del trinquete: una exención que ya no aplica —porque alguien sí
  # la puso en el menú, o porque la ruta desapareció— tiene que salir de la lista.
  # Si no, la lista se infla y deja pasar huérfanas nuevas sin que nadie las vea.
  test "no sobran exenciones" do
    nav = leer("app/views/layouts/_sidebar_admin.html.erb") +
          leer("app/controllers/dashboard_controller.rb")
    nombres = indices_de_admin.keys

    sobran = EXENTAS.keys.reject { |n| nombres.include?(n) && !nav.include?("#{n}_path") }

    assert_empty sobran, <<~MSG
      Estas exenciones ya no hacen falta: la ruta no existe, o la pantalla sí
      está en el menú. Sacalas de EXENTAS.

      #{sobran.join("\n")}
    MSG
  end

  private

  # Los `index` de admin que son una pantalla en sí: sin las anidadas (la lista
  # de tareas de UN paquete no es una entrada de menú), sin el portal del
  # cliente y sin las de sesión.
  def indices_de_admin
    Rails.application.routes.routes.each_with_object({}) do |r, acc|
      next unless r.verb == "GET"
      next unless r.defaults[:action] == "index"
      next if r.name.blank?

      controlador = r.defaults[:controller].to_s
      next if controlador.start_with?("cuenta/", "rails/", "active_storage/", "turbo/")
      # Las de autenticación se llegan sin haber entrado: no son entradas de un
      # menú que solo existe una vez adentro.
      next if controlador.in?(%w[sessions passwords registrations])

      ruta = r.path.spec.to_s.sub("(.:format)", "")
      # Anidada: depende de un padre, así que no es una entrada de menú.
      next if ruta.count(":") > 0

      acc[r.name] = ruta
    end
  end

  def leer(ruta) = Rails.root.join(ruta).read
end
