require "test_helper"

class CleanEmptyPreAlertasJobTest < ActiveJob::TestCase
  test "soft-deletes empty pre-alertas older than 30 days" do
    old_empty = PreAlerta.create!(
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:aereo),
      titulo: "Test",
      estado: "pre_alerta",
      created_at: 31.days.ago
    )

    CleanEmptyPreAlertasJob.perform_now

    assert_not_nil old_empty.reload.deleted_at
  end

  test "does not delete pre-alertas with paquetes" do
    pa = pre_alertas(:activa)
    assert pa.pre_alerta_paquetes.any?

    pa.update_column(:created_at, 31.days.ago)

    CleanEmptyPreAlertasJob.perform_now

    assert_nil pa.reload.deleted_at
  end

  test "does not delete recent empty pre-alertas" do
    recent_empty = PreAlerta.create!(
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:aereo),
      titulo: "Test",
      estado: "pre_alerta",
      created_at: 5.days.ago
    )

    CleanEmptyPreAlertasJob.perform_now

    assert_nil recent_empty.reload.deleted_at
  end

  test "does not delete already anulados" do
    old_anulado = PreAlerta.create!(
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:aereo),
      titulo: "Test",
      estado: "anulado",
      created_at: 31.days.ago
    )

    CleanEmptyPreAlertasJob.perform_now

    assert_nil old_anulado.reload.deleted_at
  end

  # 2026-10-08 · «Signos del servidor» mostró 32 fallidos de este job, todos
  # «La validación falló: Título no puede estar en blanco». Una pre-alerta
  # vieja sin título tumbaba el job entero y no se limpiaba ninguna. Borrar es
  # marcar `deleted_at`: no depende de que el resto pase las validaciones.
  test "una pre-alerta vieja sin título se borra igual, y no frena a las demás" do
    sin_titulo = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo), titulo: "x",
                                   estado: "pre_alerta", created_at: 40.days.ago)
    sin_titulo.update_column(:titulo, "")
    con_titulo = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo), titulo: "Test",
                                   estado: "pre_alerta", created_at: 35.days.ago)

    assert_nothing_raised { CleanEmptyPreAlertasJob.perform_now }

    assert_not_nil sin_titulo.reload.deleted_at
    assert_not_nil con_titulo.reload.deleted_at
  end
end
