require "application_system_test_case"

# C30-10 · Dos cosas que Jorge y Yusef vieron en la PESA el 2026-10-09.
#
# El foco: *"la nota del cliente, al darle entendido acá, no regresas"* — y
# *"otro error, no se regresó aquí"*. Cerrar un modal **con el dedo** dejaba el
# campo de escaneo con cara de enfocado, pero lo que tecleaba la pistola no
# entraba. Con Enter no pasaba, y por eso los tests de antes —que cierran con
# Enter— daban verde con el bug puesto. Acá todo se cierra con `click_on`, que
# es lo que hace la pantalla táctil.
#
# Las notas: *"esas notas que salieron, salieron a dos pero repetidas… porque yo
# lo escribí a uno"*. La nota de grupo salía como «Nota especial» y otra vez
# como «Notas de consolidación», la copia que Miami le pone a la caja.
class MedicionFocoYNotasTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:medidor))
  end

  def caja(tracking, cliente: clientes(:juan))
    p = Paquete.create!(tracking: tracking, cliente: cliente, tipo_envio: tipo_envios(:cer),
                        sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                        descripcion: "Zapatos", peso: 2)
    p.update!(estado: "en_aduana")
    p.reload
  end

  def escanear(codigo) = find("#codigo_medicion").send_keys(codigo, :enter)
  def foco = page.evaluate_script("document.activeElement.id")

  # La prueba de verdad del foco no es `activeElement`, que mentía: es que la
  # **siguiente** caja que lee la pistola entre a la mesa.
  def la_pistola_sigue_andando(paquete, cuantas)
    assert_no_selector "dialog[open]", wait: 5
    assert_equal "codigo_medicion", foco
    escanear(paquete.numero_recepcion)
    assert_selector "[data-medicion-target='mesa'] li", count: cuantas, wait: 5
  end

  def consolidado(*paquetes, nota: nil)
    pa = PreAlerta.create!(numero_documento: "PA-F#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, estado: "pre_alerta",
                           titulo: "Consolidado de prueba", creado_por_tipo: "usuario",
                           creado_por_id: users(:admin).id, notas_grupo: nota)
    paquetes.each do |p|
      pa.pre_alerta_paquetes.create!(tracking: p.tracking, descripcion: "Bulto", fecha: Date.current, paquete: p)
      # Como queda la caja en producción después de que Miami la recibe: con
      # la nota de grupo **copiada** (`PreAlertaPaquete.link_tracking!`, PR-D2).
      p.update_column(:notas_consolidacion, nota) if nota
    end
    pa
  end

  test "la nota de grupo sale una vez, aunque la caja la traiga copiada, y «Entendido» con el dedo devuelve la pistola" do
    primera = caja("1ZFOCO000000001")
    segunda = caja("1ZFOCO000000002")
    pa = consolidado(primera, segunda, nota: "test")

    visit medicion_index_path
    escanear(primera.numero_recepcion)

    assert_selector "dialog[open]", text: "Notas del cliente", wait: 5
    assert_selector "[data-medicion-target='notasLista'] li", count: 1
    assert_selector "[data-medicion-target='notasLista'] li", text: pa.numero_documento
    within("dialog[open]") { click_on "Entendido" }

    # La segunda caja trae la misma nota: ni se abre el modal ni suma al botón.
    la_pistola_sigue_andando(segunda, 2)
    assert_no_selector "dialog[open]"
    assert_selector "[data-medicion-target='notasBotonTexto']", text: "1 nota del cliente"
  end

  test "el modal rojo cerrado con el dedo devuelve la pistola" do
    primera = caja("1ZFOCO000000003")

    visit medicion_index_path
    escanear("NOEXISTE-123")
    assert_selector "dialog[open]", text: "No se encontró", wait: 5
    within("dialog[open]") { click_on "Entendido" }

    la_pistola_sigue_andando(primera, 1)
  end

  test "«quitar el último escaneado» con el dedo devuelve la pistola" do
    primera = caja("1ZFOCO000000004")
    ajena = caja("1ZFOCO000000005", cliente: clientes(:maria))
    segunda = caja("1ZFOCO000000006")

    visit medicion_index_path
    escanear(primera.numero_recepcion)
    assert_selector "[data-medicion-target='mesa'] li", count: 1, wait: 5
    escanear(ajena.numero_recepcion)
    assert_selector "dialog[open]", text: "Es otro cliente", wait: 5
    within("dialog[open]") { click_on "Quitar el último escaneado" }

    la_pistola_sigue_andando(segunda, 2)
  end

  test "«dejarla de lado» del consolidado ya medido con el dedo devuelve la pistola" do
    medida = caja("1ZFOCO000000009")
    pa = consolidado(medida)
    MedirBulto.new(user: users(:medidor)).guardar!(paquete_ids: [ medida.id ], volumenes: [ { peso: "6" } ])
    tarde = caja("1ZFOCO000000010")
    pa.pre_alerta_paquetes.create!(tracking: tarde.tracking, descripcion: "Bulto", fecha: Date.current, paquete: tarde)
    otra = caja("1ZFOCO000000011", cliente: clientes(:maria))

    visit medicion_index_path
    escanear(tarde.numero_recepcion)
    assert_selector "dialog[open]", text: "Traé el resto del estante", wait: 5
    within("dialog[open]") { click_on "Dejarla de lado" }

    la_pistola_sigue_andando(otra, 1)
  end
end
