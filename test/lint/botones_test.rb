require "test_helper"

# El trinquete de los botones.
#
# PR-BTN.2. `PR-BTN.1` arregló el componente; esto es lo que impide que la app
# se vuelva a desarmar. Sin un lint, en un mes hay otra vez 67 strings de clases
# distintos para hacer lo mismo — el componente existía desde antes y aun así el
# 82% de los botones se seguían escribiendo a mano.
#
# ── Cómo arranca verde con 229 violaciones ────────────────────────────────
#
# Con un presupuesto por archivo que **falla en las dos direcciones**:
#
#   subir  → metiste un botón crudo nuevo, usá `ButtonComponent`
#   bajar  → migraste y no actualizaste el número
#
# Sin la segunda mitad el trinquete no traba: el presupuesto queda inflado y
# deja lugar para botones crudos nuevos que nadie ve entrar.
#
# `bin/rails botones:presupuesto` imprime los hashes listos para pegar. Bajar
# la línea base tiene que costar 10 segundos o nadie lo hace, y el mensaje de
# falla de acá abajo ya dice qué archivo se movió y para qué lado.
#
# ── Los que NO se migran nunca ────────────────────────────────────────────
#
# Algunos archivos tienen botones que se quedan crudos a propósito, porque su
# forma es incompatible con el `inline-flex items-center` del componente:
#
#   · las tarjetas-botón de tipo de envío en /etiquetar (envuelven un partial)
#   · los CTA de las pantallas de sesión (`w-full rounded-xl active:scale-[0.98]`)
#   · los adornos absolutos dentro de un input (ojo de contraseña, limpiar fecha)
#   · las pills de filtro con clases interpoladas activo/inactivo
#   · el cromo del sidebar
#
# Van en el mismo presupuesto que el resto: crudo a propósito sigue siendo
# crudo, y su número tampoco puede subir solo. Lo que NO están es exentos de
# accesibilidad — eso lo cubre PR-BTN.3.
class BotonesTest < ActiveSupport::TestCase
  PRESUPUESTO = {
    # A7-17: sube de 10 a 11. El aviso de "este paquete es de otro tipo de
    # envío" dejó de ser un banner y pasó a modal bloqueante, y sus dos salidas
    # son tarjetas —título arriba, explicación abajo— iguales a las tres del
    # modal de duplicado que ya estaban crudas en este archivo. Esa forma no
    # entra en el `inline-flex items-center` del componente.
    "app/views/etiquetar/index.html.erb"                     => 11,
    # A7-20: la × que quita una caja del repetidor. Vive adentro de un
    # <template> y es un icono de 16px pegado al borde de la fila — la forma no
    # entra en el `inline-flex items-center` del componente.
    #
    # PR-C7.17: se mudó de `entrega_personal/_cajas_repetidor` al componente,
    # que ahora usan las dos pantallas.
    # La × de quitar una caja. Se mudó del componente al partial cuando el
    # <li> pasó a ser uno solo para el <template> y para las filas que pinta
    # el servidor. Es el mismo botón, en otro archivo.
    "app/views/shared/_caja_fila.html.erb"                   => 1,
    # La × de quitar un correo de aviso de la ficha del cliente. Mismo botón y
    # mismo motivo que el de la caja: un icono chico adentro de una fila que se
    # repite, con su `aria-label`.
    "app/views/clientes/_correo_fila.html.erb"               => 1,
    # PR-C7.17: `app/components` entró al censo con este PR, y este apareció
    # solo. Es legítimo y no puede migrar: `RowActionComponent` **es** la
    # alternativa a los botones crudos, así que envolverlo en `ButtonComponent`
    # sería circular. Queda declarado para que se vea que se lo miró.
    "app/components/row_action_component.html.erb"           => 1,
    # PR-BTN.5: bajó de 15 a 9. Los que quedan crudos lo están a propósito:
    # "Cambiar" / "Asignar" / "Vincular a un cliente" son acciones de texto
    # dentro de una frase —un botón con borde ahí partiría la oración— y los dos
    # "Cerrar" son la × del encabezado de un modal.
    "app/views/paquetes/show.html.erb"                       => 9,
    "app/views/paquetes/_form.html.erb"                      => 12,
    "app/views/ventas/show.html.erb"                         => 8,
    "app/views/cotizaciones/show.html.erb"                   => 7,
    "app/views/cuenta/pre_alertas/edit.html.erb"             => 4,
    "app/views/pre_facturas/edit.html.erb"                   => 5,
    "app/views/tareas/index.html.erb"                        => 5,
    "app/views/caja/show.html.erb"                           => 4,
    "app/views/entregas/show.html.erb"                       => 4,
    "app/views/notas_credito/show.html.erb"                  => 4,
    "app/views/notas_debito/show.html.erb"                   => 4,
    "app/views/paquetes/index.html.erb"                      => 4,
    "app/views/cuenta/cotizaciones/show.html.erb"            => 3,
    "app/views/cuenta/facturas/index.html.erb"               => 3,
    "app/views/cuenta/pre_alertas/_buscar_modal.html.erb"    => 3,
    "app/views/cuenta/pre_alertas/_paquete_fields.html.erb"  => 3,
    "app/views/cuenta/pre_alertas/index.html.erb"            => 3,
    "app/views/layouts/application.html.erb"                 => 3,
    "app/views/paquetes/_estado_transition_modal.html.erb"   => 3,
    "app/views/paquetes/reimprimir_etiquetas.html.erb"       => 3,
    "app/views/pre_alertas/index.html.erb"                   => 3,
    "app/views/shared/_emitir_nota_modal.html.erb"           => 3,
    "app/views/cotizaciones/index.html.erb"                  => 2,
    # RP-20: los cuatro botones de probar sonidos pasaron a ButtonComponent.
    # Quedan los dos del diálogo (abrir y "Listo").
    "app/views/shared/_sonido_config.html.erb"               => 2,
    "app/views/cuenta/facturas/show.html.erb"                => 2,
    "app/views/cuenta/pre_alertas/new.html.erb"              => 2,
    "app/views/cuenta/recibos/show.html.erb"                 => 2,
    "app/views/entregas/index.html.erb"                      => 2,
    "app/views/entregas/new.html.erb"                        => 2,
    "app/views/financiamientos/show.html.erb"                => 2,
    "app/views/manifiestos/index.html.erb"                   => 2,
    "app/views/passwords/edit.html.erb"                      => 2,
    "app/views/pre_alertas/show.html.erb"                    => 2,
    "app/views/pre_facturas/_autorizacion_modal.html.erb"    => 2,
    "app/views/pre_facturas/new.html.erb"                    => 2,
    "app/views/recibos/show.html.erb"                        => 2,
    # Baja de 2 a 1: se fue el `button_to` del interruptor de redondeo. El que
    # queda es "Eliminar" de cada fila.
    "app/views/servicios/index.html.erb"                     => 1,
    "app/views/sessions/new.html.erb"                        => 2,
    "app/views/shared/_confirm_modal.html.erb"               => 2,
    "app/views/bitacora_autorizaciones/index.html.erb"       => 1,
    "app/views/categoria_precios/_form.html.erb"             => 1,
    "app/views/clientes/_form.html.erb"                      => 1,
    "app/views/cotizaciones/_form.html.erb"                  => 1,
    "app/views/cuenta/dashboard/index.html.erb"              => 1,
    "app/views/cuenta/notas_credito/show.html.erb"           => 1,
    "app/views/cuenta/notas_debito/show.html.erb"            => 1,
    "app/views/egresos_caja/index.html.erb"                  => 1,
    "app/views/egresos_caja/new.html.erb"                    => 1,
    "app/views/empresas/edit.html.erb"                       => 1,
    "app/views/empresas/show.html.erb"                       => 1,
    "app/views/entregas/edit.html.erb"                       => 1,
    "app/views/financiamientos/new.html.erb"                 => 1,
    "app/views/ingresos_caja/index.html.erb"                 => 1,
    "app/views/ingresos_caja/new.html.erb"                   => 1,
    "app/views/layouts/cuenta.html.erb"                      => 1,
    "app/views/manifiestos/_form.html.erb"                   => 1,
    "app/views/manifiestos/show.html.erb"                    => 1,
    "app/views/motivos_retencion/_form.html.erb"             => 1,
    "app/views/notas_credito/_form.html.erb"                 => 1,
    "app/views/notas_credito/index.html.erb"                 => 1,
    "app/views/notas_credito/new.html.erb"                   => 1,
    "app/views/notas_debito/_form.html.erb"                  => 1,
    "app/views/notas_debito/index.html.erb"                  => 1,
    "app/views/notas_debito/new.html.erb"                    => 1,
    "app/views/panel_contexto/show.html.erb"                 => 1,
    "app/views/passwords/new.html.erb"                       => 1,
    "app/views/pins/edit.html.erb"                           => 1,
    "app/views/plantillas_notas_cliente/_form.html.erb"      => 1,
    "app/views/pre_facturas/index.html.erb"                  => 1,
    "app/views/pre_facturas/show.html.erb"                   => 1,
    "app/views/proveedores/_form.html.erb"                   => 1,
    "app/views/recibos/index.html.erb"                       => 1,
    "app/views/reempaques/index.html.erb"                    => 1,
    "app/views/reempaques/new.html.erb"                      => 1,
    "app/views/registrations/new.html.erb"                   => 1,
    "app/views/servicios/_form.html.erb"                     => 1,
    "app/views/servicios_extra/_form.html.erb"               => 1,
    "app/views/shared/_plantillas_notas.html.erb"            => 1,
    "app/views/shared/_tercero_field.html.erb"               => 1,
    "app/views/shared/_theme_toggle.html.erb"                => 1,
    "app/views/sucursales/_form.html.erb"                    => 1,
    "app/views/sucursales/index.html.erb"                    => 1,
    "app/views/tareas/_form.html.erb"                        => 1,
    "app/views/tarifas_recolecta/_form.html.erb"             => 1,
    "app/views/tasa_cambio/show.html.erb"                    => 1,
    "app/views/users/_form.html.erb"                         => 1,
    "app/views/ventas/edit.html.erb"                         => 1,
    "app/views/ventas/index.html.erb"                        => 1
  }.freeze

  BLANCO_SOBRE_TEAL = {
    "app/views/caja/show.html.erb"                         => 2,
    "app/views/cotizaciones/show.html.erb"                 => 2,
    "app/views/shared/_emitir_nota_modal.html.erb"         => 2,
    "app/views/cuenta/cotizaciones/show.html.erb"          => 1,
    "app/views/cuenta/pre_alertas/_buscar_modal.html.erb"  => 1,
    "app/views/cuenta/pre_alertas/edit.html.erb"           => 1,
    "app/views/egresos_caja/new.html.erb"                  => 1,
    "app/views/entregas/edit.html.erb"                     => 1,
    "app/views/entregas/index.html.erb"                    => 1,
    "app/views/entregas/new.html.erb"                      => 1,
    "app/views/entregas/show.html.erb"                     => 1,
    "app/views/financiamientos/show.html.erb"              => 1,
    "app/views/ingresos_caja/index.html.erb"               => 1,
    "app/views/ingresos_caja/new.html.erb"                 => 1,
    "app/views/manifiestos/show.html.erb"                  => 1,
    "app/views/paquetes/_form.html.erb"                    => 1,
    "app/views/paquetes/show.html.erb"                     => 1,
    "app/views/pre_facturas/edit.html.erb"                 => 1,
    "app/views/reempaques/index.html.erb"                  => 1,
    "app/views/tareas/index.html.erb"                      => 1,
    "app/views/ventas/show.html.erb"                       => 1
  }.freeze

  test "no entran botones crudos nuevos" do
    subieron, _bajaron, huerfanos = comparar(PRESUPUESTO, BotonesCrudos.censo)

    assert_empty huerfanos + subieron, <<~MSG
      Botones escritos a mano donde el presupuesto no los espera.

      Usá `ButtonComponent` (ver docs/07_design_system.md, sección Botones).
      Si de verdad tiene que ser crudo —tarjeta, CTA de auth, adorno de
      input— corré `bin/rails botones:presupuesto`, pegá el hash y dejá un
      comentario de por qué.

      #{(huerfanos + subieron).join("\n")}
    MSG
  end

  test "el trinquete tambien traba para abajo" do
    _subieron, bajaron, _huerfanos = comparar(PRESUPUESTO, BotonesCrudos.censo)

    assert_empty bajaron, <<~MSG
      Migraste botones y no bajaste el presupuesto. Dejarlo inflado le abre
      lugar a botones crudos nuevos que el lint no vería entrar.

      Corré `bin/rails botones:presupuesto` y pegá el hash.

      #{bajaron.join("\n")}
    MSG
  end

  test "no hay texto blanco sobre el teal de marca" do
    # 2.46:1, cuando WCAG AA pide 4.5:1. `cec-teal-dark` tampoco salva
    # (3.39:1). La regla del sistema es `text-cec-navy-dark` encima del teal,
    # que da 6.69:1 — el FONDO de marca no se toca.
    #
    # Este hash tiene que llegar a {} cuando termine la migración.
    real = BotonesCrudos.censo { |src| BotonesCrudos.contar_blanco_sobre_teal(src) }
    subieron, bajaron, huerfanos = comparar(BLANCO_SOBRE_TEAL, real, que: "blanco sobre teal")

    assert_empty huerfanos + subieron, <<~MSG
      Texto blanco sobre `bg-cec-teal` — 2.46:1, ilegible.
      Encima del teal va `text-cec-navy-dark`.

      #{(huerfanos + subieron).join("\n")}
    MSG
    assert_empty bajaron, "Arreglaste contraste y no bajaste el hash:\n#{bajaron.join("\n")}"
  end

  test "el presupuesto no nombra archivos que ya no existen" do
    # Una entrada fantasma es presupuesto gratis: si mañana alguien crea un
    # archivo con ese nombre, arranca con permiso para N botones crudos.
    fantasmas = (PRESUPUESTO.keys | BLANCO_SOBRE_TEAL.keys).reject do |ruta|
      File.exist?(Rails.root.join(ruta))
    end

    assert_empty fantasmas,
      "El presupuesto nombra archivos borrados:\n#{fantasmas.join("\n")}"
  end

  private

  # `que` nombra lo que se está contando, porque el mismo comparador sirve para
  # los botones crudos y para el blanco sobre teal. Sin eso, arreglar un
  # contraste devolvía "ya no tiene botones crudos" y mandaba a buscar la cosa
  # equivocada.
  def comparar(esperado, real, que: "botones crudos")
    subieron = []
    bajaron = []
    huerfanos = []

    real.each do |ruta, n|
      limite = esperado[ruta]
      if limite.nil?
        huerfanos << "  #{ruta}: #{n} (sin presupuesto)"
      elsif n > limite
        subieron << "  #{ruta}: #{limite} → #{n}"
      elsif n < limite
        bajaron << "  #{ruta}: bajá el presupuesto de #{limite} a #{n}"
      end
    end

    esperado.each_key do |ruta|
      next if real.key?(ruta) || !File.exist?(Rails.root.join(ruta))

      bajaron << "  #{ruta}: ya no tiene #{que}, sacalo del presupuesto"
    end

    [ subieron, bajaron, huerfanos ]
  end
end
