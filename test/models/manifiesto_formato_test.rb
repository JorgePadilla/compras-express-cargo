require "test_helper"

# PR-D1.d: nuevo formato anual `M<letra-sucursal><año 4-dig><contador 6-dig>`.
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

  test "Manifiesto con sucursal_origen Miami genera MMYYYYNNNNNN" do
    m = crear_manifiesto(
      empresa_manifiesto: empresa_manifiestos(:pronto),
      sucursal_origen: sucursales(:miami)
    )
    anio = m.created_at.year
    assert_match(/\AMM\d{4}\d{6}\z/, m.numero)
    assert_match(/\AMM#{anio}/, m.numero)
  end

  test "Manifiesto con sucursal_origen SPS (Zerón) genera MSYYYYNNNNNN" do
    m = crear_manifiesto(
      empresa_manifiesto: empresa_manifiestos(:pronto),
      sucursal_origen: sucursales(:zeron_sps)
    )
    anio = m.created_at.year
    assert_match(/\AMS#{anio}\d{6}\z/, m.numero)
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
