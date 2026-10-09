require "test_helper"

# PR-C6.46: que la pre-alerta de admin y la del portal no se vuelvan a separar.
#
# Las dos dibujaban la misma tarjeta con clases distintas y se fueron
# distanciando solas, sin que nadie decidiera distanciarlas: el portal quedó
# `rounded-2xl` con degradado y título `text-2xl` navy, admin `rounded-xl` plano
# con título `text-sm` gris. Jorge lo vio de entrada: *"cuando entrás a
# pre-alerta cliente se mira diff a admin"*.
#
# Restilar admin a mano lo arregla hoy y lo rompe de nuevo en tres meses. Este
# lint es lo que lo sostiene: la tarjeta sale de `FormSectionComponent` o no
# sale.
class SeccionesDeFormularioTest < ActiveSupport::TestCase
  VISTAS = Rails.root.glob("app/views/{pre_alertas,cuenta/pre_alertas}/**/*.erb")

  # Una tarjeta de sección escrita a mano: fondo blanco o degradado, con radio
  # y sombra. No cuenta un `bg-white` suelto (un dropdown, un modal).
  TARJETA_A_MANO = /class="[^"]*\b(?:bg-white|bg-gradient-to-br from-white)\b[^"]*\brounded-(?:xl|2xl)\b[^"]*\bshadow-sm\b/

  # Lo que todavía dibuja su propia tarjeta y NO entra en este PR. `index` y
  # `show` son otro patrón —lista y detalle— y el `edit` del portal es una
  # pantalla aparte. Se anotan con su número para que crecer duela.
  PRESUPUESTO = {
    "app/views/cuenta/pre_alertas/edit.html.erb" => 7,
    "app/views/cuenta/pre_alertas/index.html.erb" => 1,
    "app/views/cuenta/pre_alertas/show.html.erb" => 8,
    "app/views/pre_alertas/show.html.erb" => 7
  }.freeze

  test "las pantallas migradas no escriben la tarjeta a mano" do
    reales = VISTAS.each_with_object({}) do |archivo, cuenta|
      n = archivo.read.scan(TARJETA_A_MANO).size
      cuenta[archivo.relative_path_from(Rails.root).to_s] = n if n.positive?
    end

    nuevos = reales.reject { |vista, n| PRESUPUESTO[vista] == n }
    sobrantes = PRESUPUESTO.keys - reales.keys

    assert_empty nuevos,
                 "tarjetas escritas a mano donde el presupuesto no las espera.\n" \
                 "Usá `FormSectionComponent`. Si de verdad tiene que ser cruda, " \
                 "actualizá PRESUPUESTO con un comentario de por qué.\n" \
                 "#{nuevos.map { |v, n| "  #{v}: #{PRESUPUESTO[v] || 0} → #{n}" }.join("\n")}"
    assert_empty sobrantes, "estas ya no tienen tarjetas crudas: bajá el presupuesto\n#{sobrantes.join("\n")}"
  end

  # Cuántas secciones tiene cada pantalla. Contar y no solo preguntar "¿usa el
  # componente?" es lo que agarra que se pierda UNA de siete — que es como
  # empiezan a separarse otra vez.
  SECCIONES = {
    "app/views/pre_alertas/new.html.erb" => 5,
    # 8 = las 4 fichas de arriba (número, cliente, tipo, estado) + servicio,
    # referencia, notas y la tabla de paquetes.
    "app/views/pre_alertas/edit.html.erb" => 8,
    "app/views/cuenta/pre_alertas/new.html.erb" => 3
  }.freeze

  test "las dos pre-alertas arman todas sus secciones con el mismo componente" do
    reales = SECCIONES.keys.to_h do |vista|
      [ vista, Rails.root.join(vista).read.scan(/FormSectionComponent\.new/).size ]
    end

    assert_equal SECCIONES, reales,
                 "si una sección dejó de pasar por el componente, ahí empieza a divergir de nuevo"
  end

  # Las que este PR migró. El resto de `pre_alertas/` —`index`, `show`, el
  # `edit` del portal— sigue sin modo oscuro y NO entra acá: se arregla cuando
  # se migren, no de contrabando.
  MIGRADAS = %w[
    app/views/pre_alertas/new.html.erb
    app/views/pre_alertas/edit.html.erb
    app/views/pre_alertas/_paquete_card.html.erb
    app/views/pre_alertas/_paquete_row.html.erb
    app/views/cuenta/pre_alertas/new.html.erb
    app/views/cuenta/pre_alertas/_paquete_fields.html.erb
    app/helpers/formulario_helper.rb
    app/components/form_section_component.rb
  ].map { |v| Rails.root.join(v) }.freeze

  test "ningun navy queda sin su variante oscura en lo migrado" do
    # `text-cec-navy` sobre gris-900 da 1.69:1 — fue el peor defecto de la
    # auditoría de contraste y estaba justo en la pantalla más usada.
    huerfanos = MIGRADAS.flat_map do |archivo|
      sin_comentarios(archivo).scan(/text-cec-navy(?!-)(?!\s+dark:)([^"']{0,40})/).map do |resto|
        "#{archivo.relative_path_from(Rails.root)}: text-cec-navy#{resto.first}"
      end
    end

    assert_empty huerfanos, "navy sin `dark:` al lado:\n#{huerfanos.join("\n")}"
  end

  private

  # Los comentarios nombran las clases para explicar por qué son así —este
  # mismo archivo lo hace— y contarlos convierte una explicación en un fallo.
  def sin_comentarios(archivo)
    archivo.read
           .gsub(/<%#.*?%>/m, "")
           .gsub(/^\s*#.*$/, "")
  end
end
