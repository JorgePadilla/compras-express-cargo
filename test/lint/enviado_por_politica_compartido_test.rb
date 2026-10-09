require "test_helper"

# «Enviado según política», escrito una sola vez — el gemelo de
# `retener_compartido_test`. C18-06: Yusef pidió *"una listita igual como la
# otra"*, y la lección de la otra es que las copias se separan.
class EnviadoPorPoliticaCompartidoTest < ActiveSupport::TestCase
  PANTALLAS = %w[
    app/views/etiquetar/index.html.erb
    app/views/entrega_personal/new.html.erb
    app/views/paquetes/_form.html.erb
  ].freeze

  COMPONENTE = "app/components/enviado_por_politica_component.html.erb".freeze

  test "las tres pantallas renderizan el mismo componente" do
    sin_componente = PANTALLAS.reject { |v| leer(v).include?("EnviadoPorPoliticaComponent.new") }

    assert_empty sin_componente, "estas pantallas no ofrecen el control desde el componente"
  end

  test "ninguna pantalla escribe la casilla ni los motivos a mano" do
    a_mano = PANTALLAS.select do |vista|
      src = sin_comentarios(leer(vista))
      src.match?(/check_box\s+:enviado_por_politica/) || src.match?(/motivo_envio_politica_ids/)
    end

    assert_empty a_mano
  end

  test "ninguna vista consulta el catalogo por su cuenta" do
    consultan = Dir.glob(Rails.root.join("app/views/**/*.erb")).select do |archivo|
      File.read(archivo).match?(/MotivoEnvioPolitica\s*\./)
    end

    assert_empty consultan.map { |a| a.sub("#{Rails.root}/", "") }
  end

  test "el componente no escribe los motivos en HTML" do
    src = leer(COMPONENTE)

    assert_includes src, "collection_check_boxes"
    MotivoEnvioPolitica.limit(5).pluck(:nombre).each do |nombre|
      assert_no_match(/>#{Regexp.escape(nombre)}</, src)
    end
  end

  test "el componente no lleva ningun campo obligatorio" do
    assert_no_match(/required/, sin_comentarios(leer(COMPONENTE)))
  end

  test "el portal del cliente no lo tiene, y es a proposito" do
    # Es una explicación que Miami le da al cliente, no algo que el cliente marca.
    src = leer("app/views/cuenta/pre_alertas/_paquete_fields.html.erb")

    assert_no_match(/enviado_por_politica|EnviadoPorPoliticaComponent/, src)
  end

  private

  def leer(ruta) = Rails.root.join(ruta).read
  def sin_comentarios(src) = src.gsub(/<%#.*?%>/m, "")
end
