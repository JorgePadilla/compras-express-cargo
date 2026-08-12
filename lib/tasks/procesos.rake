# Los diagramas de proceso que se le mandan a Yusef.
#
# Ver `lib/procesos_pdf.rb`: los flujos están escritos como datos, no como
# dibujo suelto, así que hay un test que verifica que el diagrama no mienta —
# que cada ruta y cada estado que nombra existan de verdad.
namespace :docs do
  desc "Genera el PDF de los diagramas de proceso"
  task procesos_pdf: :environment do
    require "prawn"
    require "prawn/table"
    require Rails.root.join("lib/procesos_pdf")

    destino = Rails.root.join("docs/entregables/procesos_para_yusef.pdf")
    FileUtils.mkdir_p(destino.dirname)

    doc = ProcesosPdf.new
    doc.render_file(destino)

    puts "  ✓ #{destino.relative_path_from(Rails.root)}"
    puts "    #{doc.huecos.size} pasos marcados como pendientes: " \
         "#{doc.huecos.map { |h| h[:titulo] }.join(', ')}"
  end
end
