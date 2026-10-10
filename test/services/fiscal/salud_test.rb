require "test_helper"

# PR-F1.4 · El panel de salud de «Facturación SAR», con el reloj congelado.
#
# Fixtures: SPS (000-001) tiene el CAI ficticio 1–5000, que vence a un año;
# Humuya y San Manuel no tienen ninguno.
class Fiscal::SaludTest < ActiveSupport::TestCase
  setup do
    @sps = puntos_de_emision(:sps)
    @ficticia = autorizaciones_sar(:ficticia)
    @hoy = Date.new(2026, 10, 10)
    @ficticia.update_columns(fecha_limite_emision: @hoy + 200)
  end

  def fila(punto = @sps, tipo = "01")
    Fiscal::Salud.new(punto, tipo, al: @hoy).fila
  end

  test "con CAI vigente y lejos de los límites, verde, con el número que sigue" do
    travel_to(@hoy.in_time_zone(Fiscal::ZONA).change(hour: 10)) do
      f = fila
      assert_equal :verde, f.estado
      assert_equal "000-001-01-00000001", f.siguiente
      assert_equal 5000, f.quedan
      assert_equal 200, f.dias
      assert f.ficticia?
    end
  end

  test "sin autorización, rojo: la sucursal no puede facturar" do
    f = fila(puntos_de_emision(:tgu))
    assert_equal :rojo, f.estado
    assert_equal "Esta sucursal no puede facturar", f.no_puede
    assert_includes f.motivos, "No tiene autorizaciones cargadas"
  end

  test "a 30 días ámbar, a 31 verde" do
    @ficticia.update_columns(fecha_limite_emision: @hoy + 31)
    assert_equal :verde, fila.estado

    @ficticia.update_columns(fecha_limite_emision: @hoy + 30)
    assert_equal :ambar, fila.estado
    assert_includes fila.motivos, "Vence en 30 días"
  end

  test "vencida ayer, rojo; y si le quedaron números, el aviso del Art. 42" do
    @ficticia.update_columns(fecha_limite_emision: @hoy - 1)
    f = fila
    assert_equal :rojo, f.estado
    assert_match(/Ninguna autorización vigente cubre/, f.motivos.first)
    assert_equal [ @ficticia.cai ], f.vencidas_con_sobrantes.map(&:cai)
  end

  test "ámbar con el 10 % del rango, y nunca por debajo de 100 números" do
    # Rango de 5000: el 10 % son 500.
    correlativos_fiscales(:sps_factura).update!(ultimo: 4499)
    assert_equal :verde, fila.estado, "quedan 501"
    correlativos_fiscales(:sps_factura).update!(ultimo: 4500)
    assert_equal :ambar, fila.estado, "quedan 500"
    assert_includes fila.motivos, "Quedan 500 números"

    # Rango de 300: el 10 % serían 30, pero el mínimo es 100.
    @ficticia.update_columns(rango_fin: 300)
    correlativos_fiscales(:sps_factura).update!(ultimo: 199)
    assert_equal :verde, fila.estado, "quedan 101"
    correlativos_fiscales(:sps_factura).update!(ultimo: 200)
    assert_equal :ambar, fila.estado, "quedan 100"
  end

  test "si el CAI siguiente ya está cargado a continuación, quedar pocos números no es aviso" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 4900)
    AutorizacionSar.create!(punto_de_emision: @sps, tipo_documento: "01", cai: "CAI-SIGUIENTE",
                            rango_inicio: 5001, rango_fin: 10_000, fecha_limite_emision: @hoy + 300)
    assert_equal :verde, fila.estado
  end

  test "faltan datos del emisor: rojo, con lo que falta" do
    sucursales(:humuya_tgu).update!(direccion: nil)
    AutorizacionSar.create!(punto_de_emision: puntos_de_emision(:tgu), tipo_documento: "01", cai: "CAI-TGU",
                            rango_inicio: 1, rango_fin: 100, fecha_limite_emision: @hoy + 300)

    f = fila(puntos_de_emision(:tgu))
    assert_equal :rojo, f.estado
    assert_includes f.faltan_del_emisor, Fiscal::Emisor::FALTA_LA_DIRECCION
  end

  test "sin RTN de la empresa, falta el RTN" do
    Empresa.connection.execute("UPDATE empresas SET rtn = NULL")
    assert_equal [ "RTN de la empresa (14 dígitos)" ], fila.faltan_del_emisor
  end

  test "las notas aparecen solo en el punto que tiene algo cargado de ese tipo" do
    assert_equal [ "01" ], Fiscal::Salud.tipos_de(@sps)
    AutorizacionSar.create!(punto_de_emision: @sps, tipo_documento: "06", cai: "CAI-NC", rango_inicio: 1,
                            rango_fin: 1000, fecha_limite_emision: @hoy + 300)
    assert_equal %w[01 06], Fiscal::Salud.tipos_de(@sps)
    nc = Fiscal::Salud.de_todos(al: @hoy).find { |f| f.punto == @sps && f.tipo == "06" }
    assert_equal :verde, nc.estado
    assert_equal "No puede emitir notas de crédito", nc.no_puede
  end
end
