require "test_helper"

# PR-BTN.1: el botón del sistema.
#
# La auditoría encontró 334 elementos con forma de botón, 67 strings de clases
# distintos, y defectos de contraste medibles:
#
#   · blanco sobre `cec-teal`     2.46:1  (WCAG AA pide 4.5:1 para texto)
#   · blanco sobre `cec-danger`   3.76:1
#   · `dark:text-cec-navy-light`  1.69:1  ← el "Limpiar (F2)" de /etiquetar,
#                                           ilegible en modo oscuro
#
# Y **1 de 131 botones tenía estilo de foco**.
#
# Este archivo no existía. Sin él, cualquiera de esos arreglos se puede
# deshacer sin que nada avise.
class ButtonComponentTest < ViewComponent::TestCase
  # ── Contraste: cada assert lleva su ratio ──

  test "todos los variants traen anillo de foco" do
    # EL test de este archivo. Cubre los variants de hoy y los que vengan: uno
    # nuevo que nazca sin anillo rompe la suite sin que nadie se acuerde de
    # escribirle un test. Antes de PR-BTN.1 ninguno lo tenía.
    sin_foco = ButtonComponent::VARIANTS.each_key.reject do |variant|
      render_inline(ButtonComponent.new(variant: variant)) { "Accion" }
      page.has_selector?("button.foco-cec")
    end

    assert_empty sin_foco,
      "estos variants no muestran dónde está el foco: #{sin_foco.join(', ')}"
  end

  test "el anillo de foco existe de verdad en el CSS" do
    # `foco-cec` es una clase propia, no una utilidad de Tailwind: si nadie la
    # define, el test de arriba pasa y el anillo no se ve en ningún lado.
    css = File.read(Rails.root.join("app/assets/tailwind/application.css"))

    # Anclado al principio de línea a propósito: `assert_includes` con
    # ".foco-cec:focus-visible" pasaba de rebote por la regla de `.dark`, que
    # lo contiene como substring — o sea que renombrar la regla clara no
    # rompía nada.
    assert_match(/^\.foco-cec:focus-visible \{/, css)
    assert_match(/^\.dark \.foco-cec:focus-visible \{/, css)
  end

  test "el boton teal lleva tinta navy, no blanca" do
    # 2.46:1 → 6.69:1. El FONDO de marca no cambia (decisión de Jorge): lo que
    # cambia es la letra.
    render_inline(ButtonComponent.new(variant: :teal)) { "Guardar" }

    assert_selector "button.bg-cec-teal.text-cec-navy-dark"
    assert_no_selector "button.text-white"
  end

  test "primary es navy plano, no gradiente" do
    # El gradiente solo lo tenían los 59 botones ya migrados; los 46 crudos de
    # la app siempre fueron planos. Gana lo que ya se ve.
    render_inline(ButtonComponent.new(variant: :primary)) { "Nuevo" }

    assert_selector "button.bg-cec-navy"
    assert_no_selector "button[class*='bg-gradient-to-r']"
  end

  test "danger usa red-600, no cec-danger" do
    # Blanco sobre #EF4444 da 3.76:1; sobre #DC2626 da 4.83:1. Los botones
    # crudos ya usaban red-600 — el componente era el que estaba mal.
    render_inline(ButtonComponent.new(variant: :danger)) { "Borrar" }

    assert_selector "button.bg-red-600"
    assert_no_selector "button.bg-cec-danger"
  end

  test "outline_navy en oscuro va a gold, no a navy-light" do
    # #2D3A7B sobre gray-900 da 1.69:1 — el peor defecto de la auditoría, y
    # estaba en /etiquetar, la pantalla que más se usa.
    render_inline(ButtonComponent.new(variant: :outline_navy)) { "Limpiar" }

    assert_selector "button[class*='dark:text-cec-gold']"
    assert_no_selector "button[class*='dark:text-cec-navy-light']"
  end

  test "warning usa amber-700, no amber-600" do
    # Blanco sobre #D97706 da 3.19:1; sobre #B45309 da 5.02:1.
    render_inline(ButtonComponent.new(variant: :warning)) { "Reintentar" }

    assert_selector "button.bg-amber-700"
    assert_no_selector "button.bg-amber-600"
  end

  test "purple ya no es un variant" do
    # Cero usos, y `purple` está en la lista prohibida del design system.
    assert_not ButtonComponent::VARIANTS.key?(:purple)
    assert_raises(KeyError) { render_inline(ButtonComponent.new(variant: :purple)) { "x" } }
  end

  # ── Que un error se note ──

  test "un variant desconocido revienta en vez de publicar un boton sin estilo" do
    assert_raises(KeyError) { render_inline(ButtonComponent.new(variant: :inventado)) { "x" } }
  end

  test "un size desconocido revienta" do
    assert_raises(KeyError) { render_inline(ButtonComponent.new(size: :gigante)) { "x" } }
  end

  # ── Nombre accesible ──

  test "un boton de solo icono sin label no se puede renderizar" do
    # La auditoría encontró 11 así: el lector de pantalla anuncia "botón" y
    # nada más. Falla al renderizar porque un error en desarrollo es barato y
    # un botón mudo en producción no se descubre nunca.
    error = assert_raises(ArgumentError) do
      render_inline(ButtonComponent.new(icon: "trash"))
    end

    assert_match(/label/, error.message)
  end

  test "con label sale el aria-label y el icono queda oculto al lector" do
    # El `aria-hidden` lo pone el gem `heroicon`, no nosotros. El test está
    # igual: si una actualización del gem se lo lleva, el icono pasa a
    # anunciarse y el botón queda con dos nombres.
    render_inline(ButtonComponent.new(icon: "trash", label: "Borrar caja"))

    assert_selector "button[aria-label='Borrar caja']"
    assert_selector "svg[aria-hidden='true']"
  end

  test "el tamano del icono sigue al del boton" do
    # `icon_size` existía desde siempre y NO hacía nada: el gem antepone
    # `h-6 w-6` y en el CSS `.w-6` va después de `.w-4`, así que ganaba el
    # default. Todos los iconos salían a 24px, hasta en un botón `text-xs`.
    render_inline(ButtonComponent.new(icon: "trash", size: :xs)) { "Borrar" }
    assert_selector "svg.w-4.h-4"
    assert_no_selector "svg.w-6"

    render_inline(ButtonComponent.new(icon: "trash", size: :md)) { "Borrar" }
    assert_selector "svg.w-5.h-5"
    assert_no_selector "svg.w-6"
  end

  test "con texto no hace falta label" do
    render_inline(ButtonComponent.new(icon: "trash")) { "Borrar" }

    assert_selector "button", text: "Borrar"
  end

  # ── El tipo, que rompe callado ──

  test "el boton sale con type=button por defecto" do
    # Sin esto, un botón dentro de un <form> envía el formulario al clickearlo.
    # Es exactamente lo que pasaba en /entrega_personal: "Limpiar" reseteaba el
    # form Y lo enviaba, porque ni el handler ni el tag lo evitaban.
    render_inline(ButtonComponent.new) { "Limpiar" }

    assert_selector "button[type='button']"
  end

  test "type submit se respeta" do
    render_inline(ButtonComponent.new(type: "submit")) { "Guardar" }

    assert_selector "button[type='submit']"
  end

  # ── Las tres formas de renderizarse ──

  test "con href es un link" do
    render_inline(ButtonComponent.new(href: "/clientes")) { "Ver" }

    assert_selector "a[href='/clientes']"
  end

  test "con method distinto de get es un form" do
    # Un <a> con method: depende de Turbo y no funciona sin JS.
    render_inline(ButtonComponent.new(href: "/paquetes/1", method: :delete)) { "Borrar" }

    assert_selector "form[action='/paquetes/1'][method='post']"
    assert_selector "input[name='_method'][value='delete']", visible: :hidden
  end

  test "confirm viaja como turbo_confirm" do
    render_inline(ButtonComponent.new(href: "/x", method: :delete, confirm: "¿Seguro?")) { "Borrar" }

    assert_selector "[data-turbo-confirm='¿Seguro?']"
  end

  # ── Deshabilitado ──

  test "deshabilitado sin href es un button disabled" do
    render_inline(ButtonComponent.new(disabled: true)) { "Guardar" }

    assert_selector "button[disabled]"
  end

  test "deshabilitado con href es un span, no un link muerto" do
    # Un <a> deshabilitado no existe en HTML.
    render_inline(ButtonComponent.new(href: "/x", disabled: true)) { "Ver" }

    assert_selector "span[role='button'][aria-disabled='true']"
    assert_no_selector "a[href]"
    assert_text "(deshabilitado)"
  end

  test "un boton deshabilitado no responde al atajo" do
    render_inline(ButtonComponent.new(href: "/x", disabled: true, shortcut: "F10")) { "Guardar" }

    assert_no_selector "[data-shortcut]"
  end

  # ── Lo que el caller manda tiene que sobrevivir ──

  test "los data del caller sobreviven al merge del atajo" do
    # 79 de los 131 botones crudos llevan `data-action`, y varios llevan
    # targets de Stimulus. Pisar el hash `data` los rompería en silencio.
    render_inline(ButtonComponent.new(
      shortcut: "F10",
      data: { action: "click->etiquetar#guardar", etiquetar_target: "submitBtn" }
    )) { "Guardar" }

    assert_selector "button[data-shortcut='F10']"
    assert_selector "button[data-etiquetar-target='submitBtn']"
    assert_selector "button[data-action='click->etiquetar#guardar']"
  end

  test "shortcut_label_only muestra la tecla pero no la registra" do
    # `keyboard_shortcuts_controller` le hace click a cualquier
    # `[data-shortcut]`. Si la pantalla ya escucha esa tecla, la acción corre
    # dos veces — en /entrega_personal el segundo showModal() sobre un <dialog>
    # abierto tiraba InvalidStateError.
    render_inline(ButtonComponent.new(shortcut: "F2", shortcut_label_only: true)) { "Limpiar" }

    assert_text "(F2)"
    assert_no_selector "[data-shortcut]"
  end

  test "la clase del caller se suma, no reemplaza" do
    render_inline(ButtonComponent.new(class: "w-full")) { "Guardar" }

    assert_selector "button.w-full.bg-cec-navy"
  end

  test "renderizar dos veces la misma instancia no pierde clase ni data" do
    # `call` hacía `@attrs.delete(:class)` y `@attrs.delete(:data)`: la segunda
    # pasada salía sin nada de lo que el caller había mandado.
    componente = ButtonComponent.new(class: "w-full", data: { action: "click->x#y" })

    render_inline(componente) { "Guardar" }
    render_inline(componente) { "Guardar" }

    assert_selector "button.w-full[data-action='click->x#y']"
  end
end
