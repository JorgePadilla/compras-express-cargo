require "test_helper"

# PR: que los avisos de las dos pantallas de Miami no se vuelvan a separar.
#
# Yusef probó staging y reportó **dos veces** que no le avisaba a qué sucursal
# iba la caja: una en `/etiquetar` y otra en `/entrega_personal`. Eran dos
# causas distintas del mismo tipo de falla:
#
#   · en `/etiquetar`, `_fillClienteFromPreAlerta` era una COPIA de
#     `_alSeleccionarCliente`: se copiaron las notas del cliente y se olvidó el
#     aviso de sucursal. El comentario decía "misma lógica para mantener
#     consistencia" y no lo era.
#   · en `/entrega_personal` el aviso **no existía**, aunque el mixin de
#     autocomplete siempre le pasó la sucursal — la tiraba.
#
# Los dos fallaban EN SILENCIO: nadie se entera de un aviso que no salió.
class AvisosDeClienteTest < ActiveSupport::TestCase
  ETIQUETAR = Rails.root.join("app/javascript/controllers/etiquetar_controller.js")
  EP        = Rails.root.join("app/javascript/controllers/entrega_personal_controller.js")

  test "las dos pantallas avisan a que sucursal va la caja" do
    sin_aviso = { "etiquetar" => ETIQUETAR, "entrega personal" => EP }
                  .reject { |_, archivo| archivo.read.include?("_mostrarSucursal(") }

    assert_empty sin_aviso.keys,
                 "una pantalla de Miami dejó de avisar la sucursal de retiro"
  end

  test "el autofill de pre-alerta no reimplementa el gancho, lo llama" do
    # Es la causa exacta de lo que reportó Yusef: dos caminos que fijan el
    # cliente, uno con aviso y otro sin. Si `_fillClienteFromPreAlerta` vuelve a
    # tocar los banners por su cuenta, se separaron de nuevo.
    metodo = ETIQUETAR.read[/_fillClienteFromPreAlerta\(data\)\s*\{.*?\n  \}/m]
    assert metodo, "no se encontró _fillClienteFromPreAlerta"

    assert_includes metodo, "this._alSeleccionarCliente("
    assert_no_match(/notasBannerTarget|_mostrarSucursal\(/, metodo,
                    "volvió a pintar los banners por su cuenta en vez de usar el gancho")
  end

  test "el aviso de sucursal sale de un solo partial" do
    # Escrito dos veces, una pantalla se queda con el texto viejo.
    vistas = %w[app/views/etiquetar/index.html.erb app/views/entrega_personal/new.html.erb]

    vistas.each do |vista|
      src = Rails.root.join(vista).read
      assert_includes src, 'render "shared/aviso_sucursal_retiro"', "#{vista} no usa el partial"
      assert_no_match(/Separar esta caja/, src, "#{vista} escribe el aviso a mano")
    end
  end

  test "el tracking secundario se revisa y se limpia igual que el primario" do
    # Yusef: "aquí no me dio alerta del Secundario". El campo no tenía ninguna
    # acción: un número ya usado no avisaba, y lo que escupía la pistola entraba
    # crudo.
    src = Rails.root.join("app/views/etiquetar/index.html.erb").read
    campo = src[/f\.text_field :tracking_secundario.*?%>/m]
    assert campo, "no se encontró el campo de tracking secundario"

    assert_includes campo, "etiquetar#checkTrackingSecundario"
    assert_includes campo, "tracking-input#sanitize"
  end

  test "el server manda la sucursal del cliente al reconocer una pre-alerta" do
    # La otra mitad del mismo olvido: el JSON traía las notas del cliente y no
    # su sucursal, así que aunque el front la pidiera no había qué mostrar.
    src = Rails.root.join("app/controllers/paquetes_controller.rb").read
    info = src[/def detect_pre_alerta_match.*?\n  end/m]

    assert_includes info, "cliente_sucursal_retiro"
  end
end
