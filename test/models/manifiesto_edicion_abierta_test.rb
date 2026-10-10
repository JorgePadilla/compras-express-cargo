require "test_helper"

# C30-06 · El manifiesto finalizado se abre con «Editar» y se vuelve a cerrar.
#
# Yusef, 2026-10-09: *"hay dos cosas que ocupo [en] el manifiesto: uno, cambiar
# etiquetas, y dos, eliminar paquetes que no se fueron"* · *"después de
# finalizado lo necesitamos corregir, porque a veces después de finalizado
# agregamos algo que se quedaba"* · *"que le demos un botón que diga editar… y
# ya podemos editarlo todo otra vez, pero que presionen el botón"*.
class ManifiestoEdicionAbiertaTest < ActiveSupport::TestCase
  setup do
    @supervisor = users(:supervisor_miami)
    @digitador = users(:digitador)
    @manifiesto = manifiestos(:creado)   # lleva CER, sin sucursal de entrega
    @cer = tipo_envios(:cer)

    @adentro = paquetes(:empacado)
    @adentro.update_columns(tipo_envio_id: @cer.id)
    @caja = @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @supervisor)
    @manifiesto.meter!(@adentro, user: @supervisor, caja_manifiesto: @caja)

    resultado = FinalizarManifiesto.new(@manifiesto, user: @supervisor).call
    assert_not resultado.bloqueado?, "la fixture tiene que poder finalizarse"
    @manifiesto.reload
    @adentro.reload
    assert_equal "enviado_honduras", @adentro.estado
  end

  # ── Cuándo se puede abrir ───────────────────────────────────────────────

  # PR-C30.14 · **Cambia a propósito.** Hasta acá decía «un oficial enviado se
  # puede reabrir; abierto, en aduana o recibido, no»: el límite de C30-06 era
  # nuestro. Jorge, 2026-10-10, sobre el 21 (recibido): *"esta pantalla de
  # editar me debería dejar editar todo lo que está en el manifiesto"*.
  # Decisión de Jorge, pendiente de confirmar con Yusef.
  test "un oficial finalizado se reabre enviado, en aduana o recibido; abierto no hace falta" do
    assert_not manifiestos(:creado).tap { |m| m.estado = "creado" }.reabrible?

    %w[enviado en_aduana recibido].each do |estado|
      @manifiesto.estado = estado
      assert @manifiesto.reabrible?, "oficial #{estado}"
    end
  end

  test "el interno no se reabre en ningún estado: sus estados son otros" do
    @manifiesto.tipo = "interno"
    %w[enviado en_aduana recibido].each do |estado|
      @manifiesto.estado = estado
      assert_not @manifiesto.reabrible?, "interno #{estado}"
    end
    assert_match(/es un manifiesto interno/, @manifiesto.motivo_del_candado)
  end

  test "el supervisor de Miami lo abre, y queda quién y cuándo" do
    @manifiesto.abrir_edicion!(@supervisor)

    assert @manifiesto.reload.edicion_abierta?
    assert_equal @supervisor, @manifiesto.edicion_abierta_por
    assert_in_delta Time.current, @manifiesto.edicion_abierta_at, 5
  end

  # PR-C30.15 · El encabezado también espera al candado en el oficial
  # finalizado: *"que presionen el botón"*. El interno, que no se reabre, lo
  # sigue corrigiendo directo quien abre el candado (C21-06).
  test "el encabezado: abierto cualquiera; cerrado, solo el supervisor y con el candado abierto" do
    assert Manifiesto.find(@manifiesto.id).tap { |m| m.estado = "creado" }.encabezado_editable_por?(@digitador)

    assert_not @manifiesto.encabezado_editable_por?(@supervisor), "cerrado, ni el supervisor"
    @manifiesto.abrir_edicion!(@supervisor)
    assert @manifiesto.encabezado_editable_por?(@supervisor)
    assert_not @manifiesto.encabezado_editable_por?(@digitador), "por la ventana abierta no se cuela"

    @manifiesto.cerrar_edicion!
    @manifiesto.tipo = "interno"
    assert @manifiesto.encabezado_editable_por?(@supervisor), "interno: directo, como en C21-06"
    assert_not @manifiesto.encabezado_editable_por?(@digitador)
  end

  test "el digitador no lo puede abrir" do
    assert_raises(Manifiesto::NoSePuedeReabrir) { @manifiesto.abrir_edicion!(@digitador) }
    assert_not @manifiesto.reload.edicion_abierta?
  end

  # PR-C30.14 · Antes: «ya en aduana no se abre». Ahora se abre, y el interno es
  # el que no.
  test "en aduana y recibido también se abren; el interno no" do
    @manifiesto.update!(estado: "en_aduana")
    @manifiesto.abrir_edicion!(@supervisor)
    assert @manifiesto.reload.edicion_abierta?

    @manifiesto.cerrar_edicion!
    @manifiesto.update!(estado: "recibido")
    @manifiesto.abrir_edicion!(@supervisor)
    assert @manifiesto.reload.edicion_abierta?

    @manifiesto.cerrar_edicion!
    @manifiesto.update_columns(tipo: "interno")
    error = assert_raises(Manifiesto::NoSePuedeReabrir) { @manifiesto.reload.abrir_edicion!(@supervisor) }
    assert_match(/solo se reabren los manifiestos oficiales/, error.message)
  end

  # PR-C30.14 · Antes: «si Honduras empieza a recibir con la edición abierta, se
  # cierra sola» — era derivado de `enviado?`. Sigue derivado de `reabrible?`,
  # pero ahora en aduana también es reabrible: queda abierta hasta «Cerrar
  # edición», que es el botón que Yusef pidió apretar.
  test "si Honduras empieza a recibir con la edición abierta, sigue abierta hasta «Cerrar edición»" do
    @manifiesto.abrir_edicion!(@supervisor)
    @manifiesto.update!(estado: "en_aduana")   # lo que hace `RecibirManifiesto` al primer escaneo

    assert @manifiesto.edicion_abierta?
    assert @manifiesto.modificable_por?(@supervisor)

    @manifiesto.cerrar_edicion!
    assert_not @manifiesto.modificable_por?(@supervisor)
  end

  test "cerrar la edición lo vuelve a bloquear" do
    @manifiesto.abrir_edicion!(@supervisor)
    @manifiesto.cerrar_edicion!

    assert_not @manifiesto.reload.edicion_abierta?
    assert_nil @manifiesto.edicion_abierta_por
  end

  test "abrir y cerrar quedan en la bitácora" do
    PaperTrail.request(whodunnit: @supervisor.id.to_s) do
      @manifiesto.abrir_edicion!(@supervisor)
      @manifiesto.cerrar_edicion!
    end

    cambios = @manifiesto.versions.last(2).map { |v| v.changeset.keys }
    assert cambios.all? { |k| k.include?("edicion_abierta_at") }, cambios.inspect
    assert_equal [ @supervisor.id.to_s ] * 2, @manifiesto.versions.last(2).map(&:whodunnit)
  end

  # ── Quién puede tocar lo de adentro ───────────────────────────────────

  test "abierto lo cambia cualquiera con la sección" do
    assert manifiestos(:enviado).tap { |m| m.estado = "creado" }.modificable_por?(@digitador)
  end

  test "finalizado y cerrado, nadie" do
    assert_not @manifiesto.modificable_por?(@supervisor)
    assert_not @manifiesto.modificable_por?(@digitador)
  end

  test "reabierto, el supervisor sí y el digitador no" do
    @manifiesto.abrir_edicion!(@supervisor)

    assert @manifiesto.modificable_por?(@supervisor)
    assert_not @manifiesto.modificable_por?(@digitador),
               "un digitador no se cuela por la ventana que dejó abierta un supervisor"
  end

  # ── Los paquetes ──────────────────────────────────────────────────────

  test "el que se saca de uno finalizado vuelve a la bodega, sin fecha de enviado y sin caja" do
    assert @adentro.fecha_enviado.present?
    assert @adentro.fecha_enviado_by_user_id.present?

    @manifiesto.sacar!(@adentro)
    @adentro.reload

    assert_equal "recibido_miami", @adentro.estado
    assert_nil @adentro.manifiesto_id
    assert_nil @adentro.caja_manifiesto_id, "la 4×6 de la caja no lo puede seguir contando"
    assert_nil @adentro.fecha_enviado, "si no viajó, no puede decir que salió"
    assert_nil @adentro.fecha_enviado_by_user_id
    assert_equal 0, @manifiesto.reload.cantidad_paquetes
  end

  test "el que se agrega a uno finalizado sale a enviado como los demás, con quién" do
    tarde = paquetes(:recibido)
    tarde.tareas.update_all(estado: "realizada")
    tarde.update_columns(tipo_envio_id: @cer.id)

    @manifiesto.meter!(tarde, user: @supervisor)
    tarde.reload

    assert_equal @manifiesto.id, tarde.manifiesto_id
    assert_equal "enviado_honduras", tarde.estado
    assert_equal @supervisor.id, tarde.fecha_enviado_by_user_id
    assert_equal 2, @manifiesto.reload.cantidad_paquetes
  end

  test "con una tarea pendiente no entra, igual que no habría dejado finalizar" do
    tarde = paquetes(:recibido)
    tarde.update_columns(tipo_envio_id: @cer.id)
    assert tarde.tareas_bloqueantes_pendientes?, "la fixture trae una tarea pendiente"

    error = assert_raises(Manifiesto::NoEntra) { @manifiesto.meter!(tarde, user: @supervisor) }
    assert_match(/tareas pendientes/, error.message)

    tarde.reload
    assert_nil tarde.manifiesto_id, "no queda adentro a medias"
    assert_equal "recibido_miami", tarde.estado
  end

  test "en uno abierto, sacar también suelta la caja" do
    abierto = manifiestos(:enviado)
    abierto.update_columns(estado: "creado")
    caja = abierto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 5, user: @supervisor)
    p = paquetes(:recibido)
    p.update_columns(manifiesto_id: abierto.id, caja_manifiesto_id: caja.id)

    abierto.sacar!(p)

    assert_nil p.reload.caja_manifiesto_id
    assert_equal "recibido_miami", p.estado
  end

  # ── PR-C30.14 · Sacar y meter en uno que Honduras ya recibe ─────────────
  #
  # Decisión de Jorge, 2026-10-10: el que **llegó** se queda donde está y solo
  # pierde el manifiesto y la caja; el que no llegó vuelve a Miami como hoy; y
  # el que ya tiene pre-factura o medición no sale.

  test "recibido: el de una caja que se escaneó se queda en aduana, sin manifiesto, y con sus fechas de viaje" do
    recibir!(con_caja: true)
    assert_equal "en_aduana", @adentro.reload.estado
    enviado_el = @adentro.fecha_enviado
    aduana_el = @adentro.fecha_aduana
    assert enviado_el.present? && aduana_el.present?

    @manifiesto.sacar!(@adentro)
    @adentro.reload

    assert_equal "en_aduana", @adentro.estado, "llegó: no vuelve a Miami"
    assert_nil @adentro.manifiesto_id
    assert_nil @adentro.caja_manifiesto_id
    assert_equal sucursales(:zeron_sps).id, @adentro.sucursal_actual_id, "sigue donde aterrizó"
    assert_equal enviado_el.to_i, @adentro.fecha_enviado.to_i, "viajó: no puede decir que no salió"
    assert_equal aduana_el.to_i, @adentro.fecha_aduana.to_i
    assert_equal 0, @manifiesto.reload.cantidad_paquetes
  end

  test "en aduana: el de una caja que no se escaneó vuelve a Miami, como hoy" do
    @manifiesto.update!(estado: "en_aduana", sucursal_entrega: sucursales(:zeron_sps))
    assert_nil @caja.recibida_at

    @manifiesto.sacar!(@adentro)
    @adentro.reload

    assert_equal "recibido_miami", @adentro.estado
    assert_nil @adentro.manifiesto_id
    assert_nil @adentro.fecha_enviado
  end

  test "recibido con faltantes: lo que dice si llegó es la caja, no el barrido del cierre" do
    @manifiesto.update!(estado: "en_aduana", sucursal_entrega: sucursales(:zeron_sps))
    RecibirManifiesto.new(@manifiesto, user: @supervisor).finalizar!(con_faltantes: true)
    assert_equal "en_aduana", @adentro.reload.estado, "el cierre con faltantes lo barrió a aduana"
    assert_nil @caja.reload.recibida_at

    @manifiesto.reload.sacar!(@adentro)

    assert_equal "recibido_miami", @adentro.reload.estado
    assert_nil @adentro.sucursal_actual_id, "vuelve a Miami: no puede seguir diciendo que está en San Pedro"
  end

  test "sin caja: llegó si ya pasó de enviado; si sigue en enviado, vuelve" do
    @adentro.update_columns(caja_manifiesto_id: nil, estado: "en_aduana")
    @manifiesto.update_columns(estado: "recibido")
    @manifiesto.reload.sacar!(@adentro)
    assert_equal "en_aduana", @adentro.reload.estado

    otro = paquetes(:recibido)
    otro.update_columns(manifiesto_id: @manifiesto.id, estado: "enviado_honduras")
    @manifiesto.update_columns(estado: "en_aduana")
    @manifiesto.reload.sacar!(otro)
    assert_equal "recibido_miami", otro.reload.estado
  end

  test "enviado: el que se saca vuelve a Miami aunque la caja diga recibida" do
    @caja.update_columns(recibida_at: Time.current)   # no pasa, pero no manda: el manifiesto no llegó
    @manifiesto.sacar!(@adentro)
    assert_equal "recibido_miami", @adentro.reload.estado
  end

  test "con una pre-factura vigente no sale, y se dice cuál" do
    recibir!(con_caja: true)
    pf = pre_facturas(:pendiente_maria)
    @adentro.update_columns(pre_factura_id: pf.id)

    error = assert_raises(Manifiesto::NoSeSaca) { @manifiesto.sacar!(@adentro) }
    assert_match(/pre-factura #{pf.numero}/, error.message)
    assert_equal @manifiesto.id, @adentro.reload.manifiesto_id, "no se tocó nada"
    assert_equal @caja.id, @adentro.caja_manifiesto_id
  end

  test "con una pre-factura anulada sí sale" do
    recibir!(con_caja: true)
    pf = pre_facturas(:pendiente_maria)
    pf.update_columns(estado: "anulado")
    @adentro.update_columns(pre_factura_id: pf.id)

    @manifiesto.sacar!(@adentro)
    assert_nil @adentro.reload.manifiesto_id
  end

  test "la pre-factura se mira también por sus líneas: anular deja la línea viva, pero vigente la toma" do
    recibir!(con_caja: true)
    pf = pre_facturas(:pendiente_maria)
    # Sin callbacks a propósito: la línea suelta, sin la FK en el paquete.
    PreFacturaItem.insert_all!([ { pre_factura_id: pf.id, paquete_id: @adentro.id, concepto: "flete",
                                    subtotal: 1, created_at: Time.current, updated_at: Time.current } ])
    assert_nil @adentro.reload.pre_factura_id

    assert_raises(Manifiesto::NoSeSaca) { @manifiesto.sacar!(@adentro) }

    pf.update_columns(estado: "anulado")
    @manifiesto.sacar!(@adentro.reload)
    assert_nil @adentro.reload.manifiesto_id, "la de una anulada no la retiene"
  end

  test "con medición no sale" do
    recibir!(con_caja: true)
    @adentro.update_columns(medicion_sesion: "tanda-1")

    error = assert_raises(Manifiesto::NoSeSaca) { @manifiesto.sacar!(@adentro) }
    assert_match(/ya se midió/, error.message)
    assert_equal @manifiesto.id, @adentro.reload.manifiesto_id
  end

  test "la pistola de quitar lo dice antes de intentar" do
    recibir!(con_caja: true)
    @adentro.update_columns(medicion_sesion: "tanda-1")

    resultado = EscaneoDeManifiesto.new(@manifiesto).para_quitar(@adentro.tracking)
    assert_equal :no_se_saca, resultado.tipo
  end

  test "meter en uno recibido: llega a aduana, en la sucursal de entrega" do
    recibir!(con_caja: true)
    tarde = paquetes(:recibido)
    tarde.tareas.update_all(estado: "realizada")
    tarde.update_columns(tipo_envio_id: @cer.id)

    @manifiesto.meter!(tarde, user: @supervisor)
    tarde.reload

    assert_equal @manifiesto.id, tarde.manifiesto_id
    assert_equal "en_aduana", tarde.estado
    assert_equal sucursales(:zeron_sps).id, tarde.sucursal_actual_id
    assert_equal @supervisor.id, tarde.fecha_enviado_by_user_id, "pasó por enviado, con quién"
  end

  test "meter en uno que se está recibiendo: sale a enviado y llega cuando escaneen su caja" do
    @manifiesto.update!(estado: "en_aduana", sucursal_entrega: sucursales(:zeron_sps))
    tarde = paquetes(:recibido)
    tarde.tareas.update_all(estado: "realizada")
    tarde.update_columns(tipo_envio_id: @cer.id)

    @manifiesto.meter!(tarde, user: @supervisor)
    assert_equal "enviado_honduras", tarde.reload.estado
  end

  test "meter en uno que se está recibiendo, a una caja que ya se escaneó: llega" do
    @manifiesto.update!(sucursal_entrega: sucursales(:zeron_sps))
    RecibirManifiesto.new(@manifiesto, user: @supervisor).recibir_caja!(@caja)
    assert @manifiesto.reload.en_aduana?
    tarde = paquetes(:recibido)
    tarde.tareas.update_all(estado: "realizada")
    tarde.update_columns(tipo_envio_id: @cer.id)

    @manifiesto.meter!(tarde, user: @supervisor, caja_manifiesto: @caja)
    assert_equal "en_aduana", tarde.reload.estado
  end

  private

  # Honduras recibe: escanea la caja (si `con_caja`) y cierra la recepción.
  def recibir!(con_caja:)
    @manifiesto.update!(sucursal_entrega: sucursales(:zeron_sps))
    recepcion = RecibirManifiesto.new(@manifiesto, user: @supervisor)
    recepcion.recibir_caja!(@caja) if con_caja
    recepcion.finalizar!(con_faltantes: true)
    @manifiesto.reload
    assert @manifiesto.recibido?
  end
end
