require "test_helper"

# C21-05 · La etiqueta 4×6 del bulto.
#
# Yusef mandó la foto de la etiqueta impresa con dos anotaciones a mano. La
# primera dice qué le falta:
#
#   > **«Falta el número del manifiesto.»**
#
# Y la segunda, al lado del código de barras, para qué sirve:
#
#   > *«Se escanea al recibir en HN → actualiza estatus de paquetes de ENVIADO
#   >  → ADUANA.»*
class EtiquetaBultoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(consignatario: Consignatario.create!(nombre: "CORPORACION KARSAM"),
                        tipo_envio_proveedor: TipoEnvioProveedor.create!(nombre: "AEREO EXPRESS"),
                        es_prioridad: true)
    @caja = @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)
  end

  test "la etiqueta del bulto lleva el número del manifiesto" do
    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_response :success
    assert_includes response.body, @manifiesto.numero,
                    "es lo que Yusef anotó a mano que faltaba"
  end

  test "lleva lo que ya traía: letra, libras, medidas, consignatario y PRIORITY" do
    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    # C23-01: la letra ya no va sola, lleva su número adentro del mismo span.
    assert_select "span.letra", text: "#{@caja.letra}#{@caja.numero_bulto}"
    assert_includes response.body, "131"
    assert_includes response.body, "23x23x36"
    assert_includes response.body, "CORPORACION KARSAM"
    assert_includes response.body, "AEREO EXPRESS"
    assert_includes response.body, "PRIORITY"
  end

  test "sin prioridad no dice PRIORITY" do
    @manifiesto.update!(es_prioridad: false)

    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_not_includes response.body, "PRIORITY"
  end

  # RP-54 · El código de la caja va en **QR**, no en barras. `A7-03` había
  # dejado *"un código QR o lo que vos querás"* y Yusef eligió el 2026-08-30:
  # *"código QR, habría que instalar la gema necesaria"*.
  test "el código de la caja va en QR" do
    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_select "div.qr svg", 1
    assert_select "div.barcode", 0, "el bulto ya no lleva Code128"
  end

  # Y el QR **no se estira**: un Code128 aplastado se sigue leyendo por la
  # proporción entre barras, un QR deformado no lo lee nadie.
  test "el QR sale cuadrado" do
    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    svg = response.body[/<svg[^>]*>/]
    ancho = svg[/width="([^"]+)"/, 1]
    alto  = svg[/height="([^"]+)"/, 1]
    assert_equal ancho, alto
  end

  # La etiqueta del paquete **no** cambió: el warehouse sigue en Code128, que es
  # lo que leen las pistolas de Miami hoy.
  test "la etiqueta del paquete sigue con su código de barras" do
    paquete = paquetes(:disponible_entrega_juan)
    get etiqueta_paquete_path(paquete)

    assert_select "div.qr", 0
  end

  # El código es lo que se escanea en Honduras, así que tiene que ser el de la
  # caja — no el del manifiesto ni el del paquete.
  test "el código de barras es el de la caja, y es único entre bultos" do
    otra = @manifiesto.cajas.create!(alto: 13, largo: 13, ancho: 16, peso: 19)

    assert_not_equal @caja.codigo, otra.codigo

    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)
    assert_includes response.body, @caja.codigo
    assert_not_includes response.body, otra.codigo
  end

  test "se imprimen todas las del manifiesto de un tiro, una por página" do
    @manifiesto.cajas.create!(alto: 13, largo: 13, ancho: 16, peso: 19)

    get etiquetas_manifiesto_cajas_path(@manifiesto)

    assert_response :success
    assert_equal 2, response.body.scan(/class="bulto"/).size
  end

  # La Dymo de /etiquetar es 2.25 × 1.25 y su plantilla es singleton, con el
  # alto topado en 3 pulgadas — ese tope es la red de `etiqueta_cabe_test`. La
  # 4×6 es un formato aparte a propósito; este test lo fija para que nadie las
  # junte después sin darse cuenta.
  test "la 4×6 no usa la plantilla de la Dymo" do
    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_includes response.body, "size: 4in 6in"
    assert_not_includes response.body, "2.25in"
  end

  # ── C23 · La revisión del 2026-09-01, papel en mano ──────────────────────

  # *"Nosotros usamos la A y el 1… A 1, B el 2, C el 3."*
  # *"**Doble** porque la gente, a veces unos leen la A y otros leen el 1."*
  test "C23-01 · la letra va con su número, y el número es el de la letra" do
    segunda = @manifiesto.cajas.create!(alto: 13, largo: 13, ancho: 16, peso: 19)

    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)
    assert_select "span.letra", text: "A1"

    get etiqueta_manifiesto_caja_path(@manifiesto, segunda)
    assert_select "span.letra", text: "B2"
  end

  # *"Ponerle las libras reales, libras volumétricas, que es VLBS… y le podés
  #  poner los pies para el público."*
  test "C23-03 · las tres cifras salen rotuladas" do
    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_select "div.cifra span.u", text: "LBS"
    assert_select "div.cifra span.u", text: "VLBS"
    assert_select "div.cifra span.u", text: "PIES³"
    # 23×23×36 = 19_044 pulgadas³ → ÷166 = 114.72 VLBS, ÷1728 = 11.02 → 12 pies³
    assert_select "div.cifra span.v", text: "131"
    assert_select "div.cifra span.v", text: "114.72"
    assert_select "div.cifra span.v", text: "12"
  end

  # *"Esto estaría más bonito que estén juntos."* El peso y las medidas caían
  # separados por la letra de 58pt; ahora comparten el bloque de la derecha.
  test "C23-02 · el peso y las medidas van en el mismo bloque" do
    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_select "div.cabeza div.cifras div.medidas", text: "23x23x36"
  end

  # *"Lo último que le falta acá es a dónde va."*
  test "C23-04 · dice a dónde va" do
    @manifiesto.update!(sucursal_entrega: sucursales(:humuya_tgu))

    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_select "div.destino", text: "A: #{sucursales(:humuya_tgu).nombre.upcase}"
  end

  # El oficial puede no tenerla (en el interno es obligatoria, `A7-07`): sin
  # sucursal no se inventa un renglón vacío.
  test "C23-04 · sin sucursal de entrega no hay renglón de destino" do
    @manifiesto.update!(sucursal_entrega: nil)

    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_select "div.destino", 0
  end

  # ── C21-04 · El «No. Doc» de la caja, el `DM7155` de la pantalla vieja ─────
  #
  # La columna existía desde `PR-M3`, `caja_params` la permitía y **esta
  # etiqueta ya la imprimía** — pero no había ningún campo donde teclearla, así
  # que en la práctica siempre salía el respaldo. Estaba cableada por los dos
  # extremos y sin nada en el medio.

  test "C21-04 · la etiqueta imprime el No. Doc cuando lo tiene" do
    @caja.update!(numero_doc: "DM7155")

    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_select "div.doc", text: "DM7155"
  end

  # Y sin él sigue cayendo a la identificación de la caja, que es lo que se
  # canta en voz alta (`C23-01`). El respaldo no se toca.
  test "C21-04 · sin No. Doc cae a la letra con su número" do
    @caja.update!(numero_doc: nil)

    get etiqueta_manifiesto_caja_path(@manifiesto, @caja)

    assert_select "div.doc", text: "#{@caja.letra}#{@caja.numero_bulto}"
  end
end
