# Los tres sonidos de error, en archivo, para mandárselos a Yusef.
#
# `RP-20` prometía "te mandamos tres opciones por WhatsApp para que las oigas".
# Salen de `SonidosDeError`, que es la misma constante que el navegador toca en
# /etiquetar — no hay una versión "de mentira" para el archivo.
namespace :docs do
  desc "Renderea los tres sonidos de error a .wav para mandarlos por WhatsApp"
  task sonidos_wav: :environment do
    destino = Rails.root.join("docs/entregables/sonidos")
    FileUtils.mkdir_p(destino)

    SonidosDeError::VARIANTES.each do |variante|
      archivo = destino.join(SonidosWav.nombre_de(variante))
      SonidosWav.render_file(variante, archivo)

      puts format("  ✓ %-22s %4d ms  %6.1f KB   %s",
                  archivo.basename,
                  SonidosDeError.duracion_ms(variante),
                  archivo.size / 1024.0,
                  variante[:descripcion])
    end

    puts
    puts "  Escuchalos antes de mandarlos:  afplay #{destino.relative_path_from(Rails.root)}/*.wav"
    puts "  Si WhatsApp no los toma en .wav, pasalos a .m4a:"
    puts "    for f in #{destino.relative_path_from(Rails.root)}/*.wav; do afconvert -f m4af -d aac \"$f\"; done"
  end
end
