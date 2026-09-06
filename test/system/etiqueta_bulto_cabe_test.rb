require "application_system_test_case"

# C23 · ¿Entra todo en la 4 × 6 del bulto?
#
# Es la misma pregunta que `etiqueta_cabe_test` le hace a la Dymo, y por la
# misma razón: `.bulto` tiene alto fijo y `overflow: hidden`, así que cuando el
# contenido se pasa **se recorta en silencio**. El HTML sale entero, ningún test
# de integración se entera, y la impresora tira una etiqueta sin el pie.
#
# Hace falta ahora porque la revisión del 2026-09-01 le agregó dos cosas —el
# renglón del destino (`C23-04`) y el bloque de tres cifras (`C23-03`)— y la
# etiqueta más cargada quedó con 0.16 in de aire. Ese margen no se sostiene de
# vista: se mide.
#
# Si este test falla, lo que se baja es el tamaño del QR o los puntos de los
# renglones — **no se saca un campo**, que todos los pidió Yusef por nombre.
class EtiquetaBultoCabeTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    @manifiesto = manifiestos(:creado)
    # El caso que más renglones lleva: servicio, proveedor, PRIORITY,
    # consignatario y destino, los cinco a la vez. No es un borde inventado —
    # es un manifiesto aéreo de temporada con su casa marcada.
    @manifiesto.update!(
      consignatario: Consignatario.create!(nombre: "CORPORACION KARSAM"),
      tipo_envio_proveedor: TipoEnvioProveedor.create!(nombre: "AEREO EXPRESS"),
      sucursal_entrega: sucursales(:humuya_tgu),
      es_prioridad: true
    )
    @caja = @manifiesto.cajas.create!(alto: 46, largo: 43, ancho: 50, peso: 131.5)
  end

  test "la etiqueta con todos los campos no se desborda" do
    visit etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    contenido = medir("scrollHeight")
    etiqueta  = medir("clientHeight")

    assert_operator contenido, :<=, etiqueta,
                    "el contenido mide #{contenido}px y la 4×6 #{etiqueta}px — " \
                    "se están recortando #{contenido - etiqueta}px por abajo. " \
                    "Bajá el tamaño del QR o los puntos, no saques un campo."
  end

  # Los nombres largos son el modo real de romperla: el consignatario y la
  # sucursal vienen de catálogos que carga el equipo de Yusef, sin tope de
  # largo. Si alguno envuelve a dos renglones, se come una línea.
  test "un consignatario y una sucursal largos tampoco la desbordan" do
    @manifiesto.consignatario.update!(nombre: "CORPORACION KARSAM DE HONDURAS S DE R L")
    @manifiesto.sucursal_entrega.update!(nombre: "Bulevar Morazán Tegucigalpa")

    visit etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_operator medir("scrollHeight"), :<=, medir("clientHeight")
  end

  # C23-01 · La letra y el número tienen que decir lo mismo. Si se separan, la
  # doble identificación deja de servir para lo que Yusef la quiere —*"unos
  # leen la A y otros leen el 1"*— y pasa a ser dos datos que se contradicen.
  test "el número que se imprime es el de la letra" do
    segunda = @manifiesto.cajas.create!(alto: 13, largo: 13, ancho: 16, peso: 19)

    visit etiqueta_manifiesto_caja_path(@manifiesto, segunda)

    assert_selector "span.letra", text: "B2"
  end

  # ── C25-02 · El tipo de envío del proveedor se ajusta al ancho ───────────
  #
  # Yusef, con flecha en la etiqueta impresa: «AMPLIAR al tamaño». Y en el
  # audio: *"que llene hasta cierto punto y si se pasa que lo achique,
  # automáticamente"*. El script arranca en 30 pt y baja hasta 16 antes de
  # recortar. Esto **no se ve en el HTML** —el tamaño lo decide el navegador
  # midiendo— así que se mide en Chrome de verdad.
  test "un tipo de envío largo se achica en vez de recortarse" do
    @manifiesto.tipo_envio_proveedor.update!(nombre: "CKM MARITIMO CONSOLIDADO")

    visit etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    ancho, visible, pt = page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector(".proveedor");
        return [ el.scrollWidth, el.clientWidth, parseFloat(getComputedStyle(el).fontSize) * 72 / 96 ];
      })()
    JS

    assert_operator ancho, :<=, visible,
                    "«CKM MARITIMO CONSOLIDADO» se está recortando: el ajuste no corrió"
    assert_operator pt, :<, 28, "tendría que haber bajado de los 28 pt para caber"
    assert_operator pt, :>=, 16, "y nunca por debajo del piso legible"
  end

  # Y uno corto **no** se achica: el máximo es el máximo.
  test "un tipo de envío corto se queda en el tamaño máximo" do
    visit etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    pt = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.proveedor')).fontSize) * 72 / 96")

    assert_in_delta 28, pt, 0.5, "«AEREO EXPRESS» cabe en 28 pt y ahí se queda"
  end

  private

  def medir(propiedad)
    page.evaluate_script("document.querySelector('.bulto').#{propiedad}")
  end
end
