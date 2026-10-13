require "test_helper"

# PR-C31.11 · `C31-20`. La ficha del cliente, en solapas, para SAC.
#
# Yusef, 2026-10-12: *"todo lo que yo vea es de Jorge Padilla nada más… si me
# voy a pre-factura solo me salen las de él, si me voy a paquetes solo me salen
# los de él"* · *"todos los correos enviados, lo que falló"*.
class ClienteVistaSacTest < ActionDispatch::IntegrationTest
  setup do
    @juan = clientes(:juan)
    @sac = users(:admin).dup
    @sac.assign_attributes(email_address: "sac.c31@cec.test", rol: "sac", nombre: "Agente SAC",
                           password: "password123", password_confirmation: "password123")
    @sac.save!
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "SAC entra a la ficha y ve las seis solapas, con Resumen por defecto" do
    ingresar(@sac)
    get cliente_url(@juan)

    assert_response :success
    assert_select "nav[aria-label='Lo del cliente'] a", 6
    assert_select "nav a[aria-current=page]", text: /Resumen/
    assert_select "nav a[href=?]", cliente_path(@juan), text: /Resumen/
    # El resumen es la ficha de siempre, con las tareas abiertas.
    assert_select "h2", text: "Tareas pendientes del cliente"
  end

  test "una solapa que no existe cae en Resumen" do
    ingresar(@sac)
    get cliente_url(@juan, tab: "otra_cosa")

    assert_response :success
    assert_select "nav a[aria-current=page]", text: /Resumen/
  end

  test "cada solapa lista solo lo de ese cliente" do
    ingresar(users(:admin))

    get cliente_url(@juan, tab: "pre_alertas")
    assert_select "table[data-solapa=pre_alertas]" do
      assert_select "td", text: pre_alertas(:activa).numero_documento
      assert_select "td", text: pre_alertas(:maria_pa).numero_documento, count: 0
    end

    get cliente_url(@juan, tab: "paquetes")
    assert_select "table[data-solapa=paquetes]" do
      assert_select "td", text: paquetes(:recibido).tracking
      assert_select "td", text: paquetes(:empacado).tracking, count: 0
    end

    get cliente_url(@juan, tab: "pre_facturas")
    assert_select "table[data-solapa=pre_facturas]" do
      assert_select "td", text: pre_facturas(:borrador_juan).numero
      assert_select "td", text: pre_facturas(:pendiente_maria).numero, count: 0
    end

    get cliente_url(@juan, tab: "facturas")
    assert_select "table[data-solapa=facturas]" do
      assert_select "td", text: ventas(:pendiente_juan).numero
      assert_select "td", text: ventas(:pagada_maria).numero, count: 0
    end
  end

  test "la fila lleva al registro solo si quien mira puede abrirlo" do
    ingresar(@sac)

    # SAC entra a pre-alertas…
    get cliente_url(@juan, tab: "pre_alertas")
    assert_select "a[href=?]", pre_alerta_path(pre_alertas(:activa))

    # …pero no a /ventas: ve la factura, sin un link que termine en «sin permiso».
    get cliente_url(@juan, tab: "facturas")
    assert_select "td", text: ventas(:pendiente_juan).numero
    assert_select "a[href=?]", venta_path(ventas(:pendiente_juan)), count: 0
  end

  test "los correos: el fallido en rojo y con su error, y los de otro cliente no" do
    CorreoEnviado.create!(cliente: @juan, mailer: "PreAlertaMailer", accion: "paquete_recibido",
                          para: @juan.email, asunto: "Paquete PQ-1 recibido en Miami",
                          estado: "enviado", enviado_at: 2.hours.ago)
    CorreoEnviado.create!(cliente: @juan, mailer: "PreFacturaMailer", accion: "disponible",
                          para: @juan.email, asunto: "Su pedido PF-1 ya está disponible",
                          estado: "fallido", error: "Errno::ECONNREFUSED: connect(2) for smtp",
                          enviado_at: 1.hour.ago)
    CorreoEnviado.create!(cliente: clientes(:maria), mailer: "PreAlertaMailer", accion: "confirmacion",
                          para: clientes(:maria).email, asunto: "Pre-Alerta de María",
                          estado: "enviado", enviado_at: 1.hour.ago)

    ingresar(@sac)
    get cliente_url(@juan, tab: "correos")

    assert_select "nav a[aria-current=page]", text: /Correos\s+2/
    assert_select "tr[data-estado=fallido]", 1 do
      assert_select "td", text: /Su pedido PF-1/
      assert_select "p.text-red-700", text: /ECONNREFUSED/
      assert_select "span", text: "Falló"
    end
    assert_select "tr[data-estado=enviado]", 1
    assert_select "td", text: /Pre-Alerta de María/, count: 0
  end

  test "la solapa pagina" do
    30.times do |i|
      CorreoEnviado.create!(cliente: @juan, mailer: "PreAlertaMailer", accion: "confirmacion",
                            para: @juan.email, asunto: "Correo #{i}", estado: "enviado",
                            enviado_at: i.minutes.ago)
    end

    ingresar(@sac)
    get cliente_url(@juan, tab: "correos")
    assert_select "tr[data-estado]", 25

    get cliente_url(@juan, tab: "correos", page: 2)
    assert_select "tr[data-estado]", 5
  end
end
