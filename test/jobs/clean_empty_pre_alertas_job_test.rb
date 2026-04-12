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
end
