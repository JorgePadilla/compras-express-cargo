require "test_helper"

# PR: la fecha llega escrita en el campo, no vacía.
#
# Es lo que Jorge pidió ver en `/pre_alertas/new`. Va como test de integración
# —no de sistema— porque CI corre `rails test` y excluye `test/system`.
class PreAlertaFechaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
  end

  test "la fecha se muestra, con la de hoy" do
    get new_pre_alerta_url

    assert_response :success
    assert_includes response.body, Date.current.strftime("%d/%m/%Y")
  end

  test "no hay campo de fecha: el Tab no la puede pisar" do
    # Jorge: "dejemos la fecha read only con la default del server" y "que
    # cuando hagamos tab se salte obviamente ese campo". Un `<input readonly>`
    # seguiría entrando en el orden de tabulación; un texto no.
    get new_pre_alerta_url

    assert_select "input[name$='[fecha]']", false,
                  "sigue habiendo un input de fecha: el Tab va a pararse ahí"
  end

  test "el servidor no acepta una fecha mandada a mano" do
    # "Read only" tiene que valer también fuera de la pantalla. Si el param
    # siguiera permitido, un request armado a mano podría fechar una pre-alerta
    # en cualquier día.
    assert_difference "PreAlerta.count", 1 do
      post pre_alertas_url, params: { pre_alerta: {
        cliente_id: clientes(:juan).id, tipo_envio_id: tipo_envios(:aereo).id,
        titulo: "Sello de fecha", consolidado: false,
        pre_alerta_paquetes_attributes: {
          "0" => { tracking: "1Z999FECHA", descripcion: "X", fecha: "2020-01-05" }
        }
      } }
    end

    assert_equal Date.current, PreAlerta.order(:id).last.pre_alerta_paquetes.first.fecha
  end

  test "el template de filas nuevas tambien" do
    # Las filas que agrega el botón salen del `<template>`, que se pinta con
    # `PreAlertaPaquete.new`. Si el default no llegara ahí, la primera fila
    # tendría fecha y las siguientes no — que es peor que ninguna.
    get new_pre_alerta_url

    template = response.body[/<template[^>]*>.*?<\/template>/m]
    assert template, "no se encontró el template de filas nuevas"

    # Sin asumir orden de atributos: Rails escribe `name` AL FINAL
    # (`add_default_name_and_field`), así que un regex que lo ponga primero no
    # matchea nunca — y el test pasaría a verificar nada.
    # Ya no es un input: es el mismo sello que la primera fila.
    assert_includes template, Date.current.strftime("%d/%m/%Y")
    assert_no_match(/<input[^>]*\[fecha\]/, template)
  end
end
