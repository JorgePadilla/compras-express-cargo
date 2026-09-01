require "test_helper"

# PR-D1.d: formato anual del número de manifiesto.
#
# `RP-46`, 2026-09-01: pasó de `M<letra><año><correlativo>` a
# **`M<código-completo><año><correlativo>`**. La letra sola alcanzaba mientras
# Miami fuera la única que numeraba; con `SPS` y `SAM` —que existen las dos— el
# segundo manifiesto del año simplemente **no se podía crear**.
class ManifiestoFormatoTest < ActiveSupport::TestCase
  # C21-03: un manifiesto sin tipo de envío nuestro dejó de ser válido. Estos
  # tests son de la numeración anual, así que el tipo va por el helper.
  def crear_manifiesto(**attrs)
    Manifiesto.create!(**attrs, tipo_envios: [ tipo_envios(:cer) ])
  end

  setup do
    ManifiestoCounter.delete_all
  end

  test "Manifiesto sin sucursal_origen mantiene formato legacy MA-XXXXXX" do
    m = crear_manifiesto(empresa_manifiesto: empresa_manifiestos(:pronto))
    assert_match(/\AMA-\d{6}\z/, m.numero)
  end

  test "Manifiesto con sucursal_origen Miami genera MMIAYYYYNNNNNN" do
    m = crear_manifiesto(
      empresa_manifiesto: empresa_manifiestos(:pronto),
      sucursal_origen: sucursales(:miami)
    )
    anio = m.created_at.year
    assert_match(/\AMMIA#{anio}\d{6}\z/, m.numero)
  end

  test "Manifiesto con sucursal_origen SPS (Zerón) genera MSPSYYYYNNNNNN" do
    m = crear_manifiesto(
      empresa_manifiesto: empresa_manifiestos(:pronto),
      sucursal_origen: sucursales(:zeron_sps)
    )
    anio = m.created_at.year
    assert_match(/\AMSPS#{anio}\d{6}\z/, m.numero)
  end

  # El que motivó el cambio, y el que falla con la letra sola: `SPS` y `SAM`
  # empiezan igual, así que los dos generaban `MS<año>000001`. No era un número
  # salteado — era `RecordInvalid` y el manifiesto sin crearse.
  test "dos sucursales que empiezan con la misma letra ya no chocan" do
    sps = crear_manifiesto(sucursal_origen: sucursales(:zeron_sps))
    sam = crear_manifiesto(sucursal_origen: sucursales(:san_manuel))

    assert_not_equal sps.numero, sam.numero
    assert_match(/\AMSPS/, sps.numero)
    assert_match(/\AMSAM/, sam.numero)
  end

  test "manifiestos consecutivos de la misma sucursal incrementan el contador" do
    m1 = crear_manifiesto(empresa_manifiesto: empresa_manifiestos(:pronto),
                            sucursal_origen: sucursales(:miami))
    m2 = crear_manifiesto(empresa_manifiesto: empresa_manifiestos(:pronto),
                            sucursal_origen: sucursales(:miami))
    n1 = m1.numero[-6..].to_i
    n2 = m2.numero[-6..].to_i
    assert_equal n1 + 1, n2
  end

  test "counters independientes por sucursal en el mismo año" do
    m_miami = crear_manifiesto(empresa_manifiesto: empresa_manifiestos(:pronto),
                                  sucursal_origen: sucursales(:miami))
    m_sps = crear_manifiesto(empresa_manifiesto: empresa_manifiestos(:pronto),
                                sucursal_origen: sucursales(:zeron_sps))
    # Ambos arrancan en 1 (no comparten contador)
    assert_equal 1, m_miami.numero[-6..].to_i
    assert_equal 1, m_sps.numero[-6..].to_i
    assert_not_equal m_miami.numero, m_sps.numero
  end
end
