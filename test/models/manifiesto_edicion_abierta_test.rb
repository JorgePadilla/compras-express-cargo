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

  test "un oficial enviado se puede reabrir; abierto, en aduana o recibido, no" do
    assert @manifiesto.reabrible?
    assert_not manifiestos(:creado).tap { |m| m.estado = "creado" }.reabrible?

    @manifiesto.estado = "en_aduana"
    assert_not @manifiesto.reabrible?, "Honduras ya lo está escaneando"
    @manifiesto.estado = "recibido"
    assert_not @manifiesto.reabrible?
  end

  test "el interno no se reabre: sus estados son otros" do
    @manifiesto.tipo = "interno"
    assert_not @manifiesto.reabrible?
  end

  test "el supervisor de Miami lo abre, y queda quién y cuándo" do
    @manifiesto.abrir_edicion!(@supervisor)

    assert @manifiesto.reload.edicion_abierta?
    assert_equal @supervisor, @manifiesto.edicion_abierta_por
    assert_in_delta Time.current, @manifiesto.edicion_abierta_at, 5
  end

  test "el digitador no lo puede abrir" do
    assert_raises(Manifiesto::NoSePuedeReabrir) { @manifiesto.abrir_edicion!(@digitador) }
    assert_not @manifiesto.reload.edicion_abierta?
  end

  test "ya en aduana no se abre" do
    @manifiesto.update!(estado: "en_aduana")
    error = assert_raises(Manifiesto::NoSePuedeReabrir) { @manifiesto.abrir_edicion!(@supervisor) }
    assert_match(/recibiendo en Honduras/, error.message)
  end

  test "si Honduras empieza a recibir con la edición abierta, se cierra sola" do
    @manifiesto.abrir_edicion!(@supervisor)
    @manifiesto.update!(estado: "en_aduana")   # lo que hace `RecibirManifiesto` al primer escaneo

    assert_not @manifiesto.edicion_abierta?
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
end
