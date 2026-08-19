require "test_helper"

# Que el escaneo no apague la retención que trae la pre-alerta.
#
# Venía anotado como pendiente desde `#305` —lo que Yusef pidió el 17-ago:
# *"nos hace falta la opción de Retener en Miami en Pre Alerta de Admin"*— y
# dejó de ser opcional cuando la pre-alerta empezó a llevar también los motivos:
# si el escaneo apaga la bandera, se lleva los motivos por delante y toda la
# función no sirve de nada.
#
# La causa: el checkbox de `/etiquetar` arranca desmarcado, y un checkbox
# desmarcado manda `"0"`. Los motivos van con un `hidden` vacío que los limpia
# igual. Así que el `assign_attributes` del reconciliado apagaba lo que la
# pre-alerta acababa de traer, en el momento exacto de recibir el paquete.
class ElEscaneoNoBorraLaRetencionTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    @motivo = motivos_retencion(:danado)
  end

  test "el JSON del escaneo trae la retencion, los motivos y la nota" do
    pap = pre_alertar_retenido("1ZESCANEORET0001")

    get check_tracking_paquetes_url(tracking: pap.tracking), as: :json
    json = JSON.parse(response.body)

    assert json["pre_alerta_match"]
    assert json["retener_miami"], "el escaneo no dice que venía retenido"
    assert_equal [ @motivo.id ], json["motivo_retencion_ids"]
    assert_equal "Llegó abierto", json["notas_retencion"]
  end

  test "sin retencion el JSON lo dice igual de claro" do
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Normal", estado: "pre_alerta")
    pap = pa.pre_alerta_paquetes.create!(tracking: "1ZESCANEOSIN0001", descripcion: "x")

    get check_tracking_paquetes_url(tracking: pap.tracking), as: :json

    assert_not JSON.parse(response.body)["retener_miami"]
  end

  test "la pantalla marca la casilla en vez de dejar el formulario en blanco" do
    # La mitad del navegador. El servidor no la fuerza a propósito: el que recibe
    # tiene que poder desmarcarla si al ver el bulto decide que no —la misma
    # decisión que tomó Yusef para el aviso del secundario: *"lo va a retener, o
    # lo va a enviar así"*.
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    metodo = src[/_marcarRetencionDeLaPreAlerta\(data\)\s*\{.*?\n  \}/m]
    assert metodo, "no se encontró el marcado de la retención"

    assert_includes metodo, "paquete[retener_miami]"
    assert_includes metodo, "paquete[motivo_retencion_ids][]"
    assert_includes metodo, "paquete[notas_retencion]"
  end

  test "y el autofill de la pre-alerta lo llama" do
    # Escrito aparte pero sin llamarlo sería lo mismo que no tenerlo. Ya pasó:
    # `_fillClienteFromPreAlerta` era una copia que se olvidó del aviso de
    # sucursal, y Yusef lo reportó dos veces.
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    banner = src[/_showPreAlertaBanner\(data\)\s*\{.*?\n  \}/m]

    assert_includes banner, "_marcarRetencionDeLaPreAlerta(data)"
  end

  private

  def pre_alertar_retenido(tracking)
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Anunciado y retenido", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: tracking, descripcion: "Lo que viene",
                                   retener_miami: true,
                                   motivo_retencion_ids: [ @motivo.id ],
                                   notas_retencion: "Llegó abierto")
  end
end
