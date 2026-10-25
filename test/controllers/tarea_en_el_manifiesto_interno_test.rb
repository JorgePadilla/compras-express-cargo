require "test_helper"

# C33-09 · La nota «dejar en San Pedro» que nadie leyó. Yusef, 2026-10-24:
# *"con el sistema, en la buena práctica debería alertarte o no dejarte"* ·
# *"esas son las notas especiales que quiero poner en la prefactura de un
# paquete: que ese paquete tiene una tarea de que se tiene que quedar en San
# Pedro. Ya entendí de dónde van las tareas."*
#
# Lo que hace el manifiesto interno con una tarea que bloquea:
# - **Entra**, y se dice: al escanearlo y al empacar sin escanear.
# - **No sale**: el cierre se traba (`FinalizarManifiesto`, probado en
#   `cerrar_manifiesto_interno_test`).
# - Si la tarea se abrió con el paquete ya en el camión, al recibirlo **se
#   recibe y se dice**.
class TareaEnElManifiestoInternoTest < ActionDispatch::IntegrationTest
  setup do
    @interno = Manifiesto.create!(tipo: "interno", sucursal_origen: sucursales(:zeron_sps),
                                  sucursal_entrega: sucursales(:humuya_tgu), tipo_envios: [ tipo_envios(:cer) ])
  end

  def paquete(estado:, **extra)
    Paquete.create!(tracking: "1Z#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), sucursal: sucursales(:humuya_tgu),
                    sucursal_actual: sucursales(:zeron_sps), estado: estado, descripcion: "Perfumes", peso: 5,
                    user: users(:digitador), **extra)
  end

  def con_tarea(paquete)
    Tarea.create!(paquete: paquete, titulo: "Dejar en San Pedro", departamento: "caja")
    paquete
  end

  test "empacar sin escanear el interno nombra al que tiene la tarea" do
    trabado = con_tarea(paquete(estado: "disponible_entrega"))
    libre = paquete(estado: "disponible_entrega")

    resultado = EmpacarSinEscanear.new(@interno, user: users(:admin)).call

    assert_equal 2, resultado.agregados
    assert_equal [ trabado ], resultado.trabados
    assert_equal @interno, libre.reload.manifiesto
  end

  test "y el manifiesto con ese paquete no se finaliza" do
    trabado = con_tarea(paquete(estado: "disponible_entrega", manifiesto: @interno))

    @interno.finalizar!(user: users(:admin))

    assert_equal "disponible_entrega", trabado.reload.estado
    assert @interno.reload.creado?, "no salió"
  end

  test "al recibirlo con una tarea que se abrio en el camino, se recibe y se dice" do
    @interno.update!(estado: "enviado")
    llegado = con_tarea(paquete(estado: "enviado_sucursal", manifiesto: @interno))
    post session_url, params: { email_address: users(:supervisor_prefactura).email_address, password: "password123" }

    post escanear_recepcion_carga_url(@interno), params: { codigo: llegado.tracking }

    assert_equal "ok", response.parsed_body["resultado"]
    assert_match "Tiene tareas pendientes: Dejar en San Pedro", response.parsed_body["mensaje"]
    assert_equal "disponible_entrega", llegado.reload.estado
  end
end
