namespace :fiscal do
  desc "Lista los RTN de clientes y empresa que no son 14 digitos (solo reporta, no cambia nada)."
  task rtn_invalidos: :environment do
    hallazgos = Fiscal::RtnInvalidos.detectar

    if hallazgos.empty?
      puts "Todos los RTN cargados son de 14 digitos."
      next
    end

    puts format("%-8s %8s  %-40s %-22s %s", "MODELO", "ID", "NOMBRE", "RTN", "QUE HACER")
    puts "-" * 110
    hallazgos.each do |h|
      que_hacer = h.motivo == :invalido ? "corregir a mano" : "se arregla al guardar"
      puts format("%-8s %8d  %-40s %-22s %s", h.modelo, h.id, h.nombre.to_s[0, 40], h.rtn.inspect, que_hacer)
    end

    invalidos = hallazgos.count { |h| h.motivo == :invalido }
    puts "\n#{hallazgos.size} RTN fuera de formato; #{invalidos} hay que corregirlos a mano."
  end
end
