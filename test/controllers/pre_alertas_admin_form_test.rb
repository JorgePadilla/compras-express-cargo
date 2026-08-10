require "test_helper"

# PR-C6.26: los tres detalles que Yusef anotó sobre /pre_alertas/new con rol
# admin, en su página de notas del 2026-08-08:
#
#   "/pre-alertas/new pero rol Admin → **abre tarjetas de crédito en tracking**"
#   "**preseleccionar** de los dropdown"
#
# y en el audio, tecleando un tracking repetido:
#
#   "Mira, ve, cómo le di enter: ya tiene un error y **no lo detecta que ya
#    existe**."
class PreAlertasAdminFormTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
  end

  test "el tracking no le abre el autofill del navegador" do
    # Chrome le ofrecía tarjetas de crédito. El portal cliente ya se defendía;
    # el admin no.
    get new_pre_alerta_url

    campo = campo_tracking(response.body)
    assert_match(/autocomplete="off"/, campo)
    assert_match(/data-1p-ignore/, campo)
  end

  test "la fila que agrega el JS tiene las mismas defensas" do
    # Si no, el autofill volvía a aparecer apenas se agregaba un tracking más.
    get new_pre_alerta_url

    # PR-C6.44: el corte iba de ADENTRO del `name=` hasta el `>`, y eso pasaba
    # solo porque el HTML estaba escrito a mano con `name` de primero. Ahora la
    # plantilla la genera `fields_for`, que renderiza `name` e `id` AL FINAL
    # (`add_default_name_and_field` corre último), así que ese corte quedaba
    # vacío y el test pasaba a no verificar nada. Se corta el tag entero, igual
    # que el helper `campo_tracking` de acá abajo.
    plantilla = response.body[/<input[^>]*NEW_INDEX\]\[tracking\][^>]*>/].to_s
    assert_match(/autocomplete="off"/, plantilla)
    assert_match(/id="[^"]*NEW_INDEX[^"]*"/, plantilla, "la fila nueva ni siquiera tenía id")
  end

  test "el tipo de envio arranca preseleccionado" do
    # El modelo backfillea CER al guardar, así que el default YA existía —
    # simplemente no se veía, y el operario tenía que elegirlo igual.
    get new_pre_alerta_url

    cer = tipo_envios(:cer)
    assert_match(/<option selected="selected" value="#{cer.id}">/, response.body)
  end

  test "el que se preselecciona es el mismo que aplicaria el modelo" do
    # Si divergen, la pantalla miente: muestra uno y guarda otro.
    pa = PreAlerta.new(cliente: clientes(:juan), titulo: "x", creado_por_tipo: "usuario", creado_por_id: 1)
    pa.valid?

    get new_pre_alerta_url

    assert_match(/<option selected="selected" value="#{pa.tipo_envio_id}">/, response.body)
  end

  test "el form avisa si el tracking ya existe" do
    get new_pre_alerta_url

    assert_match(/data-controller="tracking-duplicado"/, response.body)
    assert_match(/data-tracking-duplicado-target="aviso"/, response.body)
    # Rails escapa el `>` del `data-action` como `&gt;`; el navegador lo
    # vuelve a leer bien.
    assert_match(/data-action="[^"]*input-(?:>|&gt;)tracking-duplicado#buscar/, response.body)
  end

  test "el aviso usa el mismo endpoint que la pistola de Miami" do
    # Así hereda su escalera de búsqueda: exacto, secundario y el código largo
    # de USPS (PR-C6.21). Reimplementarlo acá seria abrir la puerta a que se
    # separen otra vez.
    get new_pre_alerta_url

    assert_match(/data-tracking-duplicado-url-value="[^"]*check_tracking[^"]*"/, response.body)
  end

  private

  def campo_tracking(cuerpo)
    cuerpo[/<input[^>]*name="pre_alerta\[pre_alerta_paquetes_attributes\]\[0\]\[tracking\]"[^>]*>/].to_s
  end
end
