require "application_system_test_case"

# En /medicion todo lo que se aprieta se distingue de lo que tiene detrás.
#
# Jorge, 2026-10-08: *"review the accessibility in this page, some buttons
# are hard to distinguish"*. WCAG 1.4.11 pide 3:1 entre el borde de un
# componente y lo que lo rodea. Lo que no llegaba: la X de cada caja (borde
# `red-200`, 1.45:1), «Notas del cliente» (`amber-300`, 1.44:1), los íconos
# de corregir y quitar un volumen (`ghost`: sin borde ninguno), «Agregar
# volumen» (teal sobre blanco, 2.46:1), «Guardar e imprimir» (oro, 1.76:1) y
# «Sonidos» (`gray-300`, 1.47:1); y los campos, que decían `border-gray-300`
# sin la clase `border`: no tenían borde ninguno.
#
# Se mide en Chrome lo que el navegador **pinta**: el borde, o el anillo
# (`box-shadow` de `ring-*`), o si no tiene ninguno el relleno, compuesto
# sobre el fondo del que lo contiene. Los colores salen de `getComputedStyle`,
# que con Tailwind 4 son `oklch(…)`: un `<canvas>` de 1 px los pasa a sRGB y
# además hace la mezcla de los que tienen transparencia.
class MedicionSeDistingueTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:medidor))
    @cajas = 2.times.map { |i| caja("1ZDISTINGUE000#{i}") }
  end

  def caja(tracking, cliente: clientes(:juan))
    p = Paquete.create!(tracking: tracking, cliente: cliente, tipo_envio: tipo_envios(:cer),
                        sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                        descripcion: "Zapatos", peso: 2)
    p.update!(estado: "en_aduana")
    p
  end

  test "con la tanda armada y un volumen, todo botón y campo tiene canto de 3:1" do
    armar_tanda_con_un_volumen
    assert_empty sin_canto, "estos no se distinguen de su fondo (1.4.11 pide 3:1): #{sin_canto.inspect}"
  end

  test "en el modal de «es otro cliente», también" do
    armar_tanda_con_un_volumen
    otra = caja("1ZDISTINGUEOTRO", cliente: clientes(:maria))
    find("#codigo_medicion").send_keys(otra.tracking, :enter)
    assert_selector "dialog[open]", wait: 5

    assert_empty sin_canto("dialog[open]"), "en el modal no se distinguen: #{sin_canto('dialog[open]').inspect}"
  end

  test "ni «Peso real» ni las medidas tienen flechitas" do
    armar_tanda_con_un_volumen
    # `appearance: textfield` es lo que le saca las flechas a un campo
    # numérico en Chrome; las del pseudo-elemento no se pueden leer desde JS.
    %w[peso alto largo ancho].each do |campo|
      aspecto = page.evaluate_script("getComputedStyle(document.querySelector('#medicion_#{campo}')).appearance")
      assert_equal "textfield", aspecto, "#{campo} sigue con las flechitas del campo numérico"
    end
  end

  private

  def armar_tanda_con_un_volumen
    visit medicion_index_path
    @cajas.each_with_index do |c, i|
      find("#codigo_medicion").send_keys(c.tracking, :enter)
      assert_selector "[data-medicion-target='mesa'] li", count: i + 1, wait: 5
    end
    find("#codigo_medicion").send_keys(:enter)
    send_keys "10", :enter, "10", :enter, "10", :enter, "10"
    page.driver.browser.action.send_keys(:f5).perform
    assert_selector "[data-medicion-target=listaVolumenes] li", count: 1, wait: 5
  end

  # Los botones y campos visibles adentro de `raiz` cuyo canto no llega a 3:1
  # contra el fondo que tienen detrás.
  def sin_canto(raiz = "[data-controller~=medicion]")
    page.evaluate_script(<<~JS)
      (function () {
        var lienzo = document.createElement("canvas"); lienzo.width = lienzo.height = 1;
        var ctx = lienzo.getContext("2d", { willReadFrequently: true });
        function pintar(capas) {
          ctx.clearRect(0, 0, 1, 1);
          capas.forEach(function (c) { if (c) { ctx.fillStyle = "#000"; ctx.fillStyle = c; ctx.fillRect(0, 0, 1, 1); } });
          return Array.from(ctx.getImageData(0, 0, 1, 1).data);
        }
        function alfa(c) { return pintar(["#fff", c])[3] === 255 && pintar(["rgba(0,0,0,0)", c])[3] > 0; }
        function lum(p) {
          var f = function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
          return 0.2126 * f(p[0]) + 0.7152 * f(p[1]) + 0.0722 * f(p[2]);
        }
        function contraste(a, b) { var x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
        function fondoDe(el) {
          for (var p = el.parentElement; p; p = p.parentElement) {
            var bg = getComputedStyle(p).backgroundColor;
            if (alfa(bg)) return bg;
          }
          return "#fff";
        }
        var COLOR = /((?:rgba?|oklch|oklab|lab|lch|color)\\([^)]*\\))\\s+0px\\s+0px\\s+0px\\s+([\\d.]+)px/g;
        function anillo(sombra) {
          var m, ultimo = null;
          while ((m = COLOR.exec(sombra))) { if (parseFloat(m[2]) > 0) ultimo = m[1]; }
          COLOR.lastIndex = 0;
          return ultimo;
        }
        var raiz = document.querySelector(#{raiz.to_json});
        return Array.from(raiz.querySelectorAll("button, input:not([type=hidden]):not([type=radio]), select"))
          .filter(function (el) { return el.offsetParent !== null || el.closest("dialog[open]"); })
          .filter(function (el) { var r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; })
          .map(function (el) {
            var cs = getComputedStyle(el);
            var detras = fondoDe(el);
            var relleno = alfa(cs.backgroundColor) ? cs.backgroundColor : null;
            var degradado = (cs.backgroundImage.match(/(?:rgba?|oklch|oklab|color)\\([^)]*\\)/) || [])[0] || null;
            var borde = parseFloat(cs.borderTopWidth) > 0 && alfa(cs.borderTopColor) ? cs.borderTopColor : null;
            var canto = borde || anillo(cs.boxShadow) || relleno || degradado;
            var afuera = pintar(["#fff", detras]);
            var orilla = canto ? pintar(["#fff", detras, relleno || degradado, canto]) : afuera;
            var ratio = contraste(afuera, orilla);
            return { que: (el.getAttribute("aria-label") || el.textContent || el.id || el.name || "").trim().slice(0, 40), ratio: Math.round(ratio * 100) / 100 };
          })
          .filter(function (x) { return x.ratio < 3; });
      })()
    JS
  end
end
