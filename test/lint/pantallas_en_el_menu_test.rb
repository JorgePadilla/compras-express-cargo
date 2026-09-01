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

  # ── El segundo trinquete: las pantallas de adentro de un flujo ──────────
  #
  # El test de arriba mira **entradas de menú**: índices sin `:id`. Y por eso
  # dejó pasar `/manifiestos/:id/empacar`, que vivió meses sin un solo link —
  # existía, funcionaba, tenía tests y hasta estaba en la tabla de pantallas de
  # `docs/07`, pero a ella solo se llegaba escribiendo la URL.
  #
  # Una pantalla anidada es otra clase de huérfana: no le toca una entrada de
  # menú, le toca un botón en la pantalla de la que cuelga. Este test pide eso.
  #
  # Y por qué los tests no la cazaban: `empaque_controller_test` la visita por
  # helper de ruta, como nadie real hace. Cuando el test entra por una puerta
  # que el usuario no tiene, prueba otra cosa.
  EXENTAS_ANIDADAS = {
    "preview_view_component"              => "previews de ViewComponent, herramienta de desarrollo",
    "_system_test_entrypoint"             => "punto de entrada que ViewComponent monta para sus system tests",
    "rails_mandrill_inbound_health_check" => "endpoint de infraestructura de Action Mailbox",
    "new_categoria_precio"                => "PR-C7.12: las categorías se administran dentro de la Tabla de Servicios",
    "entregables_entregas"                => "lo pide el JS de /entregas para llenar la lista, no es una pantalla",
    "facturables_pre_facturas"            => "lo pide el JS de /pre_facturas, no es una pantalla",
    "edit_paquete"                        => "el paquete se edita **dentro** de su ficha; el listado enlaza a `paquete_path` con el título «Abrir paquete (Editar dentro)»",
    # Las dos de abajo son deuda encontrada por este lint, no decisiones. Se
    # anotan para que se vean; sacarlas de acá es enlazarlas o borrar la ruta.
    "edit_venta"                          => "PENDIENTE: `ventas/edit.html.erb` existe y no la enlaza nadie. Anterior a este lint; hay que decidir si se enlaza o se borra"
  }.freeze

  test "toda pantalla de adentro de un flujo se alcanza con un clic" do
    huerfanas = pantallas_anidadas.reject do |nombre, destino|
      EXENTAS_ANIDADAS.key?(nombre) || alguien_la_enlaza?(nombre, destino)
    end

    assert_empty huerfanas.keys, <<~MSG
      Estas pantallas existen y **ninguna vista las enlaza**. Se llega solo
      escribiendo la URL — o sea que para quien no las conoce, no existen.

      Poneles un botón en la pantalla de la que cuelgan, o agregalas a
      EXENTAS_ANIDADAS con el porqué.

      #{huerfanas.map { |n, d| "  #{n}_path (#{d})" }.join("\n")}
    MSG
  end

  # El contrapeso, igual que el de arriba: si el barrido deja de encontrar
  # rutas, el test pasa vacío y contento sin haber mirado nada.
  test "el barrido de anidadas de verdad encuentra pantallas" do
    assert_operator pantallas_anidadas.size, :>=, 40,
                    "el barrido dejó de enganchar: había más de 40 rutas que mirar"

    assert_includes pantallas_anidadas.keys, "manifiesto_empacar",
                    "la que motivó este lint tiene que estar entre las que mira"
  end

  private

  # Todo lo que renderiza una pantalla y **no** es una entrada de menú: los
  # `index` los cubre el test de arriba.
  def pantallas_anidadas
    Rails.application.routes.routes.each_with_object({}) do |r, acc|
      next unless r.verb == "GET"
      next if r.name.blank?
      next if r.defaults[:action] == "index"

      controlador = r.defaults[:controller].to_s
      next if controlador.start_with?("rails/", "active_storage/", "turbo/", "action_mailbox/")
      # El portal del cliente tiene su propia navegación, aparte del sidebar.
      next if controlador.start_with?("cuenta/")
      next if controlador.in?(%w[sessions passwords registrations])

      acc[r.name] = "#{controlador}##{r.defaults[:action]}"
    end
  end

  # ¿La enlaza **otra** pantalla?
  #
  # Lo de «otra» es todo el asunto, y casi se me escapa: la primera versión de
  # este test daba por alcanzable a `/manifiestos/:id/empacar` porque
  # `empaque/show.html.erb` **se enlaza a sí misma** —el selector de «¿en qué
  # caja estás empacando?»—. Una pantalla que solo se enlaza a sí misma sigue
  # sin tener puerta: se puede cambiar de caja una vez adentro, pero no entrar.
  #
  # Así que **la vista de esa misma acción** no cuenta como quien la enlaza.
  #
  # Es la vista de la acción y no el controller entero: en REST el `index` es
  # justamente quien enlaza a `new` y a `edit`, y excluir el controller completo
  # daba por huérfana media aplicación.
  def alguien_la_enlaza?(nombre, destino)
    controlador, accion = destino.split("#")
    propia = "app/views/#{controlador}/#{accion}."

    vistas.any? { |ruta, cuerpo| !ruta.start_with?(propia) && cuerpo.include?("#{nombre}_path") }
  end

  # Dónde puede vivir un link: las vistas y los componentes, con su ruta
  # relativa para poder saber de quién es cada archivo.
  def vistas
    @vistas ||= Dir.glob(Rails.root.join("app/{views,components}/**/*.{erb,rb}")).to_h { |f|
      [ Pathname.new(f).relative_path_from(Rails.root).to_s, File.read(f) ]
    }
  end

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
