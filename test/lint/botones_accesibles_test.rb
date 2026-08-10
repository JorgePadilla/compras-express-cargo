require "test_helper"

# PR-BTN.3: los botones que se quedan crudos también tienen nombre y foco.
#
# `PR-BTN.2` cuenta cuántos hay. Esto vigila que los que quedan **se puedan
# usar**. Son dos cosas distintas: un botón puede ser perfectamente consistente
# y aun así no tener nombre para un lector de pantalla.
#
# Lo que la auditoría encontró y esto impide que vuelva:
#
#   · 11 botones de solo icono sin nombre accesible — el lector anuncia
#     "botón" y nada más
#   · 7 que usan `title=` creyendo que alcanza (es el tooltip del mouse, no el
#     nombre: no lo lee un lector ni aparece con teclado)
#   · `paquetes/_form.html.erb:673` con `focus:outline-none` **sin reemplazo**:
#     le sacaba al navegador su anillo y no ponía nada
class BotonesAccesiblesTest < ActiveSupport::TestCase
  # No hay lista de permitidos, y es a propósito: **todos** los botones de la
  # app pasan. Una excepción vacía o de más es lo que esconde la próxima
  # regresión.
  test "ningun boton se queda sin nombre accesible" do
    mudos = []

    cada_boton do |archivo, tag, cuerpo, linea|
      next if tag =~ /\baria-label\b/ || tag =~ /\baria-labelledby\b/
      # Con texto visible no hace falta: el nombre sale del contenido. Se
      # descuentan los tags (el `<svg>` del icono no es texto).
      next if cuerpo.gsub(/<[^>]*>/m, "").gsub(/<%.*?%>/m, "").strip.present?
      # Un `<%= ... %>` suelto adentro puede estar imprimiendo el label.
      next if cuerpo =~ /<%=(?!\s*heroicon)/

      mudos << "  #{archivo}:#{linea}  #{tag.gsub(/\s+/, ' ')[0, 110]}"
    end

    assert_empty mudos, <<~MSG
      Botones de solo icono sin nombre accesible. Un lector de pantalla los
      anuncia como "botón" y nada más.

      Agregá `aria-label`. `title` NO alcanza: es el tooltip del mouse, no
      aparece con teclado y los lectores no lo usan como nombre.

      #{mudos.join("\n")}
    MSG
  end

  test "nadie apaga el anillo de foco sin reemplazarlo" do
    # `focus:outline-none` sin nada que lo reemplace le saca al navegador el
    # único indicador que trae de fábrica.
    apagados = []

    Dir.glob(Rails.root.join("app/views/**/*.erb")).sort.each do |ruta|
      src = File.read(ruta)
      next unless src.include?("focus:outline-none")

      BotonesCrudos.valores_de_clase(src).each do |valor|
        next unless valor.include?("focus:outline-none")
        next if valor =~ /\bfoco-cec\b/ || valor =~ /focus-visible:outline-/ ||
                valor =~ /\bfocus:ring-/ || valor =~ /\bfocus:border-/

        apagados << "  #{ruta.sub("#{Rails.root}/", '')}  #{valor[0, 100]}"
      end
    end

    assert_empty apagados, <<~MSG
      `focus:outline-none` sin reemplazo. Quien navega con teclado deja de ver
      dónde está parado.

      Agregá `foco-cec` (el anillo del sistema, definido en application.css).

      #{apagados.join("\n")}
    MSG
  end

  private

  # Recorre los `<button>` de las vistas con su contenido.
  #
  # El escaneo tiene que respetar las comillas, y no es un detalle: casi todos
  # los botones de esta app llevan `data-action="click->algo#metodo"`, que
  # tiene un `>` ADENTRO del valor. Un `<button\b([^>]*)>` corta el tag ahí, el
  # `aria-label` cae en el "cuerpo" en vez de en los atributos, y el lint pasa
  # a ser decorativo — creyendo que cada botón tiene texto visible.
  #
  # Se descubrió justamente reintroduciendo el bug: sacarle el `aria-label` a
  # un botón que lo tenía no hacía fallar nada.
  ATRIBUTOS = /(?:[^>"']|"[^"]*"|'[^']*')*/

  def cada_boton
    Dir.glob(Rails.root.join("app/views/**/*.erb")).sort.each do |ruta|
      archivo = ruta.sub("#{Rails.root}/", "")
      src = BotonesCrudos.sin_comentarios(File.read(ruta))

      src.scan(%r{<button\b(#{ATRIBUTOS})>(.*?)</button>}m) do
        tag = "<button#{Regexp.last_match(1)}>"
        cuerpo = Regexp.last_match(2)
        linea = src[0...Regexp.last_match.begin(0)].count("\n") + 1

        yield archivo, tag, cuerpo, linea
      end
    end
  end
end
