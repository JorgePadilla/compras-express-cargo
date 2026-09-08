require "test_helper"

# Actualizar en /etiquetar no puede borrar el peso que ya estaba guardado.
#
# Salió de la revisión del 2026-09-07, mirando la estación de Miami por cámara
# para entender de dónde salen los paquetes "digitados" sin peso.
#
# La secuencia que lo produce es la de siempre: el operario abre un paquete que
# ya pesa, mide otra caja, le da **Agregar** —y `cajas-repetidor#_limpiarCaptura`
# le vacía los campos de captura, que son `paquete[peso]`, `paquete[alto]`…— y
# guarda. El formulario manda `paquete[peso]=""`, `update` se lo pasa entero al
# `assign_attributes`, y como `peso` valida `allow_nil: true` el `save!` pasa sin
# quejarse. El peso se fue **en silencio**: nadie escribió nada y nadie vio nada.
#
# Los cinco campos de `CAMPOS_POR_CAJA` son los únicos que el JS vacía solo, y
# por eso son los únicos donde un blanco NO es una decisión de quien digita. En
# el resto —una nota, un tercero— borrar el texto sí es lo que quiso hacer, y
# tiene que seguir borrando: eso lo pina el último test.
class ActualizarNoBorraElPesoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    abrir_sesion(tipo_envios(:cer))
  end

  test "guardar con el peso en blanco deja el peso que ya estaba" do
    paquete = crear_pesado("1ZNOBORRAPESO001")

    # Tal cual lo manda el formulario después de apretar «Agregar»: la caja
    # nueva viaja en `paquete[cajas][…]` y los campos de captura van vacíos.
    patch actualizar_etiquetar_url(paquete), params: { paquete: {
      peso: "", alto: "", largo: "", ancho: "", cantidad_productos: "",
      descripcion: "Ropa", cajas: { "1" => { peso: "7" } }
    } }

    paquete.reload
    assert_equal 5.5.to_d, paquete.peso, "le borraron el peso guardado"
    assert_equal 10.to_d, paquete.alto, "y también el alto"
    assert_equal 12.to_d, paquete.largo
    assert_equal 8.to_d, paquete.ancho
    assert_equal 3, paquete.cantidad_productos
  end

  test "un cero explícito sí es un dato y se guarda" do
    # La otra mitad de la regla: el blanco es el JS, el cero es una persona
    # diciendo que esa caja no mide nada. Sin este test, "arreglarlo" con un
    # `.positive?` o un `compact_blank` pasaría igual de verde.
    paquete = crear_pesado("1ZNOBORRAPESO002")

    patch actualizar_etiquetar_url(paquete),
          params: { paquete: { alto: "0", descripcion: "Ropa" } }

    assert_equal 0.to_d, paquete.reload.alto, "un cero escrito a mano no es un blanco"
  end

  test "un peso nuevo sigue pisando al viejo" do
    paquete = crear_pesado("1ZNOBORRAPESO003")

    patch actualizar_etiquetar_url(paquete),
          params: { paquete: { peso: "9.25", descripcion: "Ropa" } }

    assert_equal 9.25.to_d, paquete.reload.peso, "corregir el peso es el trabajo de esta pantalla"
  end

  test "vaciar una nota sí la borra" do
    # El alcance de la regla. Los campos de texto no los vacía nadie más que
    # quien digita, así que un blanco ahí es lo que quiso hacer.
    paquete = crear_pesado("1ZNOBORRAPESO004")
    paquete.update!(notas_internas: "Venía abierta")

    patch actualizar_etiquetar_url(paquete),
          params: { paquete: { notas_internas: "", descripcion: "Ropa" } }

    assert paquete.reload.notas_internas.blank?, "borrar una nota es una decisión, no un descuido"
  end

  test "al reconciliar un esperado, el blanco tampoco pisa" do
    # `create_single` sobre un esperado hace el mismo `assign_attributes` con
    # los params crudos. Acá el operario midió solo el alto: el `peso` vacío no
    # puede llevarse por delante lo que el esperado ya traía.
    esperado = crear_esperado("1ZNOBORRAPESO005")
    esperado.update_columns(peso: 4.0)

    post etiquetar_url, params: { paquete: {
      tracking: esperado.tracking, cliente_id: clientes(:juan).id,
      descripcion: "Ropa", peso: "",
      cajas: { "1" => { alto: "11" } }
    } }

    esperado.reload
    assert_equal 4.to_d, esperado.peso, "el esperado perdió el peso al reconciliarse"
    assert_equal 11.to_d, esperado.alto
  end

  private

  def abrir_sesion(tipo)
    post iniciar_sesion_etiquetar_url, params: {
      tipo_envio_id: tipo.id, sucursal_recepcion_id: sucursales(:miami).id
    }
  end

  def crear_pesado(tracking)
    Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                    tracking: tracking, descripcion: "Ropa", estado: "recibido_miami",
                    user: users(:digitador), sucursal_recepcion: sucursales(:miami),
                    peso: 5.5, alto: 10, largo: 12, ancho: 8, cantidad_productos: 3)
  end

  def crear_esperado(tracking)
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Anunciado", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: tracking, descripcion: "Lo que viene")
    Paquete.find_by(tracking: tracking) ||
      Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                      tracking: tracking, descripcion: "Lo que viene",
                      estado: "pre_alerta_estado", user: users(:digitador))
  end
end
