require "test_helper"

# PR-D1.b: confirma que cuando cambia el estado, las fechas correspondientes
# se setean automáticamente (con quién las disparó), y que `fecha_pre_alerta`
# es inmutable (queda original).
class PaqueteEstadoFechasTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    PaperTrail.request.whodunnit = @user.id
    Current.session = Struct.new(:user).new(@user)
  end

  teardown do
    PaperTrail.request.whodunnit = nil
    Current.session = nil
  end

  test "cambio a empacado setea fecha_empacado y user" do
    p = Paquete.create!(tracking: "1Z999EF_A", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_nil p.fecha_empacado
    p.update!(estado: "empacado")
    assert_not_nil p.fecha_empacado
    assert_equal @user.id, p.fecha_empacado_by_user_id
  end

  test "cambio a aduana setea fecha_aduana y user" do
    p = Paquete.create!(tracking: "1Z999EF_B", cliente: clientes(:juan), sucursal: sucursales(:miami))
    p.update!(estado: "en_aduana")
    assert_not_nil p.fecha_aduana
    assert_equal @user.id, p.fecha_aduana_by_user_id
  end

  test "cambio a entregado setea fecha_entregado y user" do
    p = Paquete.create!(tracking: "1Z999EF_C", cliente: clientes(:juan), sucursal: sucursales(:miami))
    p.update!(estado: "entregado")
    assert_not_nil p.fecha_entregado
    assert_equal @user.id, p.fecha_entregado_by_user_id
  end

  test "fecha_pre_alerta NO se sobrescribe (es inmutable)" do
    p = Paquete.create!(tracking: "1Z999EF_PA", cliente: clientes(:juan), sucursal: sucursales(:miami),
                        estado: "pre_alerta_estado")
    primera_fecha = p.fecha_pre_alerta
    assert_not_nil primera_fecha
    sleep 1.1
    p.update!(estado: "recibido_miami")
    p.update!(estado: "pre_alerta_estado")  # vuelve al pre-alerta — fecha NO cambia
    assert_equal primera_fecha.to_i, p.reload.fecha_pre_alerta.to_i
  end

  test "estado pre_alerta_estado existe en el enum" do
    assert_includes Paquete.estados.keys, "pre_alerta_estado"
  end

  test "ESTADO_FECHA_MAP cubre todos los estados con fechas" do
    assert_equal :fecha_empacado,    Paquete::ESTADO_FECHA_MAP["empacado"]
    assert_equal :fecha_entregado,   Paquete::ESTADO_FECHA_MAP["entregado"]
    assert_equal :fecha_aduana,      Paquete::ESTADO_FECHA_MAP["en_aduana"]
    assert_equal :fecha_consolidando, Paquete::ESTADO_FECHA_MAP["consolidando_honduras"]
  end

  test "estados terminales sin fecha (anulado/retornado/desechado/retenido) no rompen" do
    %w[anulado retornado desechado retenido].each do |estado_final|
      p = Paquete.create!(tracking: "1Z999EF_TERM_#{estado_final}",
                          cliente: clientes(:juan), sucursal: sucursales(:miami))
      assert_nothing_raised { p.update!(estado: estado_final) }
    end
  end
end
