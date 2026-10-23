require "application_system_test_case"

# PR-A11Y.8 · axe-core en cada pantalla, con trinquete.
#
# Jorge, 2026-10-23: *"revisemos todo el proyecto y asegurémonos que todo sea
# accesible"*, y eligió que la revisión automática fuera con trinquete, como el
# lint de botones: lo que había ese día es el presupuesto de cada pantalla, y
# el número **falla para los dos lados**:
#
#   subir → la pantalla rompió algo de WCAG que antes cumplía
#   bajar → la arreglaste y no bajaste el número (y queda lugar para que
#           entre otra cosa sin que nadie la vea)
#
# Lo que se cuenta es cada elemento que rompe una regla de WCAG 2.1 A o AA
# (las etiquetas `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa` de axe). Las
# «buenas prácticas» de axe no entran: son opinión, no norma.
#
# `bin/rails a11y:presupuesto` corre esto en modo inventario e imprime el hash
# listo para pegar.
#
# axe se inyecta directo (`axe.min.js` de la gema `axe-core-api`) y no por su
# API de Ruby, que abre ventanas `about:blank` para juntar resultados de
# iframes: no hay iframes acá, y esas ventanas son las huérfanas que ya
# trabaron los system tests (ver `cerrar_pestanas_extra`).
class AccesibilidadTest < ApplicationSystemTestCase
  AXE_JS = Pathname(Gem.loaded_specs["axe-core-api"].full_gem_path)
             .join("node_modules/axe-core/axe.min.js").read.freeze
  REGLAS = %w[wcag2a wcag2aa wcag21a wcag21aa].freeze

  # Lo que había el 2026-10-23, después de PR-A11Y.1 a .7. Una pantalla que
  # no está acá tiene presupuesto 0: ya está limpia y así se queda.
  PRESUPUESTO = {
    "caja"                      => 2,
    "clientes"                  => 2,
    "clientes/new"              => 22,
    "clientes/show"             => 34,
    "cuenta"                    => 4,
    "cuenta/cotizaciones"       => 1,
    "cuenta/entregas"           => 1,
    "cuenta/facturas"           => 1,
    "cuenta/pre_alertas"        => 19,
    "cuenta/pre_alertas/edit"   => 11,
    "cuenta/pre_alertas/new"    => 3,
    "entrega_personal/new"      => 11,
    "entregas"                  => 2,
    "home"                      => 40,
    "manifiestos/show"          => 33,
    "paquetes"                  => 29,
    "paquetes/show"             => 82,
    "pre_alertas"               => 5,
    "pre_alertas/edit"          => 5,
    "pre_alertas/new"           => 3,
    "pre_facturas"              => 1,
    "proveedores"               => 9,
    "servicios"                 => 9,
    "sesion"                    => 2,
    "tareas"                    => 4,
    "users"                     => 7,
    "ventas"                    => 2,
  }.freeze

  PANTALLAS = {
    # El personal
    "home"                     => [ :admin, -> { root_path } ],
    "clientes"                 => [ :admin, -> { clientes_path } ],
    "clientes/new"             => [ :admin, -> { new_cliente_path } ],
    "clientes/show"            => [ :admin, -> { cliente_path(clientes(:juan)) } ],
    "paquetes"                 => [ :admin, -> { paquetes_path } ],
    "paquetes/show"            => [ :admin, -> { paquete_path(paquetes(:recibido)) } ],
    "pre_alertas"              => [ :admin, -> { pre_alertas_path } ],
    "pre_alertas/new"          => [ :admin, -> { new_pre_alerta_path } ],
    "pre_alertas/edit"         => [ :admin, -> { edit_pre_alerta_path(pre_alertas(:activa)) } ],
    "etiquetar"                => [ :admin, -> { etiquetar_path } ],
    "entrega_personal/new"     => [ :admin, -> { new_entrega_personal_path } ],
    "manifiestos"              => [ :admin, -> { manifiestos_path } ],
    "manifiestos/show"         => [ :admin, -> { manifiesto_path(manifiestos(:creado)) } ],
    "historial_manifiestos"    => [ :admin, -> { historial_manifiestos_path } ],
    "recibir_carga"            => [ :admin, -> { recepcion_carga_index_path } ],
    "guias_aduana"             => [ :admin, -> { guias_aduana_index_path } ],
    "medicion"                 => [ :admin, -> { medicion_index_path } ],
    "pre_facturas"             => [ :admin, -> { pre_facturas_path } ],
    "caja"                     => [ :admin, -> { caja_path } ],
    "ventas"                   => [ :admin, -> { ventas_path } ],
    "cotizaciones"             => [ :admin, -> { cotizaciones_path } ],
    "entregas"                 => [ :admin, -> { entregas_path } ],
    "tareas"                   => [ :admin, -> { tareas_path } ],
    "proveedores"              => [ :admin, -> { proveedores_path } ],
    "servicios"                => [ :admin, -> { servicios_path } ],
    "users"                    => [ :admin, -> { users_path } ],
    "feriados"                 => [ :admin, -> { feriados_path } ],
    # El cliente
    "sesion"                   => [ nil,      -> { new_session_path } ],
    "cuenta"                   => [ :cliente, -> { cuenta_root_path } ],
    "cuenta/pre_alertas"       => [ :cliente, -> { cuenta_pre_alertas_path } ],
    "cuenta/pre_alertas/new"   => [ :cliente, -> { new_cuenta_pre_alerta_path } ],
    "cuenta/pre_alertas/edit"  => [ :cliente, -> { edit_cuenta_pre_alerta_path(pre_alertas(:activa)) } ],
    "cuenta/facturas"          => [ :cliente, -> { cuenta_facturas_path } ],
    "cuenta/entregas"          => [ :cliente, -> { cuenta_entregas_path } ],
    "cuenta/cotizaciones"      => [ :cliente, -> { cuenta_cotizaciones_path } ]
  }.freeze

  PANTALLAS.each do |nombre, (quien, ruta)|
    test "axe: #{nombre}" do
      entrar_como(quien)
      visit instance_exec(&ruta)
      assert_selector "body", wait: 5

      violaciones = correr_axe
      total = violaciones.sum { |v| v["nodes"] }

      if ENV["AXE_PRESUPUESTO"]
        puts %(AXE_PRESUPUESTO    "#{nombre}" => #{total},)
        next
      end

      esperado = PRESUPUESTO.fetch(nombre, 0)
      detalle = violaciones.map { |v| "  #{v['id']} (#{v['impact']}): #{v['nodes']} · #{v['ejemplo']}" }.join("\n")

      assert total <= esperado, <<~MSG
        #{nombre}: #{total} elementos rompen WCAG, el presupuesto es #{esperado}.
        Algo de esta pantalla dejó de ser accesible:
        #{detalle}
      MSG
      assert total >= esperado, <<~MSG
        #{nombre}: bajó de #{esperado} a #{total}. ¡Bien! Bajá el número en
        PRESUPUESTO (o corré `bin/rails a11y:presupuesto`): si no, deja lugar
        para que entre otra cosa sin que se vea.
      MSG
    end
  end

  private

  def entrar_como(quien)
    case quien
    when :admin then ingresar(users(:admin))
    when :cliente
      visit new_session_path
      fill_in "email_address", with: clientes(:juan).codigo
      fill_in "password", with: "Cliente123!"
      click_on "Iniciar Sesion"
      assert_current_path cuenta_root_path, wait: 5
    end
  end

  # Cada regla rota, con cuántos elementos la rompen y el primero de ejemplo.
  def correr_axe
    page.execute_script(AXE_JS) unless page.evaluate_script("typeof window.axe !== 'undefined'")
    # Las entradas animadas (fade-in, stagger) pasan por opacidades intermedias,
    # y axe mide el contraste en el medio: el home daba 7 en una corrida y 16
    # en la otra. Se espera a que terminen (apagarlas dejaría en opacidad 0 lo
    # que entra animado, y axe se lo saltearía).
    using_wait_time(15) do
      page.evaluate_async_script(<<~JS)
        const listo = arguments[0]
        Promise.all(document.getAnimations().filter(a => a.effect?.getTiming().iterations !== Infinity).map(a => a.finished))
          .then(() => listo(true), () => listo(true))
      JS
    end
    # axe tarda unos segundos en una pantalla grande: el `async_script` espera
    # lo que diga `default_max_wait_time`, que es poco para esto.
    using_wait_time(30) { evaluar_axe }
  end

  def evaluar_axe
    page.evaluate_async_script(<<~JS, REGLAS)
      const [reglas, listo] = arguments
      axe.run(document, { runOnly: { type: "tag", values: reglas }, resultTypes: ["violations"] })
        .then(r => listo(r.violations.map(v => ({
          id: v.id, impact: v.impact, nodes: v.nodes.length,
          ejemplo: (v.nodes[0] && v.nodes[0].target.join(" ")) || ""
        }))))
        .catch(e => listo([{ id: "axe-error", impact: "error", nodes: 0, ejemplo: String(e) }]))
    JS
  end
end
