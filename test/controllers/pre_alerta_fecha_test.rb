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

  test "el campo de fecha llega con la de hoy" do
    get new_pre_alerta_url

    assert_response :success
    assert_select "input[name$='[fecha]'][value=?]", Date.current.to_s
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
    input = template[/<input[^>]*\[fecha\][^>]*>/]
    assert input, "el template no trae el campo de fecha"
    assert_includes input, %(value="#{Date.current}")
  end
end
