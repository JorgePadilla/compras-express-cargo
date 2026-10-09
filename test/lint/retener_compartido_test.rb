require "test_helper"

# «Retener en Miami», escrito una sola vez.
#
# Jorge, sobre `/pre_alertas/new`: *"debería comportarse igual que el de
# etiquetar y entrega personal, debería ser el mismo componente"*. Al ir a
# buscarlo no existía — había **cuatro pantallas y cuatro respuestas**:
#
#   · `/etiquetar` tenía el bloque completo.
#   · El form de `/paquetes` tenía una **copia**, ya divergida: consultaba
#     `MotivoRetencion` adentro de la vista, y los rótulos y los botones no eran
#     los mismos.
#   · `/entrega_personal` no tenía **nada**, aunque su controller carga los
#     motivos y permite los campos desde siempre. Cableado muerto.
#   · La pre-alerta tenía solo la casilla, y solo al crear.
#
# Este lint es lo que impide que vuelvan a separarse.
class RetenerCompartidoTest < ActiveSupport::TestCase
  # Cinco archivos, no cuatro: la pre-alerta lo pinta dos veces —la tarjeta de
  # crear y la fila de editar—.
  PANTALLAS = %w[
    app/views/etiquetar/index.html.erb
    app/views/paquetes/_form.html.erb
    app/views/entrega_personal/new.html.erb
    app/views/pre_alertas/_paquete_card.html.erb
    app/views/pre_alertas/_paquete_row.html.erb
  ].freeze

  COMPONENTE = "app/components/retener_miami_component.html.erb".freeze

  test "las cinco pantallas renderizan el mismo componente" do
    sin_componente = PANTALLAS.reject { |v| leer(v).include?("RetenerMiamiComponent.new") }

    assert_empty sin_componente, "estas pantallas no ofrecen la retención desde el componente"
  end

  test "ninguna pantalla escribe la casilla ni los motivos a mano" do
    # Es como se separan: alguien copia el bloque en vez de usar el componente y
    # a partir de ahí las dos evolucionan por su lado. Fue exactamente lo que
    # pasó entre /etiquetar y el form de /paquetes.
    a_mano = PANTALLAS.select do |vista|
      src = sin_comentarios(leer(vista))
      src.match?(/check_box\s+:retener_miami/) ||
        src.match?(/motivo_retencion_ids/)
    end

    assert_empty a_mano, "arman el bloque de retención por su cuenta:\n#{a_mano.join("\n")}"
  end

  test "ninguna vista consulta el catalogo de motivos por su cuenta" do
    # El form de /paquetes hacía `MotivoRetencion.activos.ordered` **dentro del
    # ERB** — la única de las cuatro que lo hacía, y por eso el bloque no se
    # podía compartir: no había cómo pasarle los motivos.
    consultan = Dir.glob(Rails.root.join("app/views/**/*.erb")).select do |archivo|
      File.read(archivo).match?(/MotivoRetencion\s*\./)
    end

    assert_empty consultan.map { |a| a.sub("#{Rails.root}/", "") },
                 "consultan el catálogo desde la vista en vez de recibirlo"
  end

  test "el componente no escribe los motivos en HTML" do
    # Si los listara a mano, agregar uno al catálogo no lo mostraría y nadie se
    # enteraría hasta que alguien preguntara por qué no aparece.
    src = leer(COMPONENTE)

    assert_includes src, "collection_check_boxes"
    MotivoRetencion.limit(5).pluck(:nombre).each do |nombre|
      assert_no_match(/>#{Regexp.escape(nombre)}</, src, "«#{nombre}» está escrito a mano")
    end
  end

  test "el componente no lleva ningun campo obligatorio" do
    # Vive adentro de un `<dialog>` cerrado. Un control `required` dentro de un
    # contenedor oculto hace que Chrome se niegue a enviar el formulario **sin
    # decir por qué** — la misma trampa que quedó anotada en `#306`.
    # Sobre el marcado, no sobre los comentarios: el porqué está escrito arriba
    # del componente y usa la palabra.
    assert_no_match(/required/, sin_comentarios(leer(COMPONENTE)))
  end

  test "el portal del cliente sigue sin el control, y es a proposito" do
    # Retener es una acción operativa de Miami y los motivos son de ellos
    # («paquete dañado», «contenido perecedero»). Yusef lo pidió para la
    # pre-alerta de **admin**. Si algún día aparece acá, que sea una decisión y
    # no un "emparejemos las pantallas".
    src = leer("app/views/cuenta/pre_alertas/_paquete_fields.html.erb")

    assert_no_match(/retener_miami|RetenerMiamiComponent/, src)
  end

  private

  def leer(ruta) = Rails.root.join(ruta).read

  # Los comentarios de ERB explican **por qué** el bloque es como es, y nombran
  # justamente lo que el lint busca. Mirarlos sería prohibir explicarse.
  def sin_comentarios(src) = src.gsub(/<%#.*?%>/m, "")
end
