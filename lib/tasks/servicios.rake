# El PDF de los servicios que se le manda a Yusef para revisar.
#
# Vive aparte de `docs.rake` porque su contenido está en una clase —
# `lib/servicios_pdf.rb`— y no hardcodeado adentro del task. Eso es lo que deja
# probarlo: los datos salen de métodos puros, y el render tiene su prueba de
# humo.
namespace :docs do
  desc "Genera el PDF de los servicios para que Yusef lo revise"
  task servicios_pdf: :environment do
    require "prawn"
    require "prawn/table"
    require Rails.root.join("lib/servicios_pdf")

    destino = Rails.root.join("docs/entregables/servicios_para_yusef.pdf")
    FileUtils.mkdir_p(destino.dirname)

    doc = ServiciosPdf.new

    # Los avisos van a la consola y NO al PDF: son para quien genera el
    # documento, no para quien lo revisa.
    avisos = doc.avisos
    if avisos.any?
      puts "\n  ⚠  Revisá esto antes de mandarlo:"
      avisos.each { |a| puts "     · #{a}" }
      puts
    end

    doc.render_file(destino)
    puts "  ✓ #{destino.relative_path_from(Rails.root)}"
  end
end
