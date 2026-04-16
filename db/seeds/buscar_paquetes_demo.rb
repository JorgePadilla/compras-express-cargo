# Demo data for the "Buscar Paquetes" modal on /cuenta/pre_alertas/:id/edit
#
# Cubre los 5 tipos de envio (EXPRESS, CER, CEM, CKA, CKM) para Juan Perez:
#   - Paquetes sueltos (sin PAP) por cada tipo consolidable
#   - Pre-alertas consolidando por cada tipo con paquetes vinculados
#   - 1 PA CKA y 1 PA CKM con paquetes vinculados (verifican el bloqueo "desde single_package")
#
# Run with:
#   bin/rails runner db/seeds/buscar_paquetes_demo.rb
#
# Idempotente: seguro de correr multiples veces. Matchea por tracking / numero_documento.

require_relative "../../config/environment" unless defined?(Rails)

# ── Cliente destino ──
juan = Cliente.find_by(nombre: "Juan", apellido: "Perez") || Cliente.find_by(codigo: "CEC-001")
unless juan
  puts "⚠️  No se encontro cliente Juan Perez ni CEC-001 — corre primero `SEED_SAMPLE_DATA=1 bin/rails db:seed`"
  exit 1
end

# ── Tipos de envio ──
TIPOS = {
  express: TipoEnvio.find_by!(codigo: "express"),
  cer:     TipoEnvio.find_by!(codigo: "cer"),
  cem:     TipoEnvio.find_by!(codigo: "cem"),
  cka:     TipoEnvio.find_by!(codigo: "cka"),
  ckm:     TipoEnvio.find_by!(codigo: "ckm")
}

digitador = User.where(rol: %w[digitador_miami supervisor_miami]).first || User.first

puts "═══ Buscar Paquetes demo seed ═══"
puts "Cliente: #{juan.codigo} (#{juan.nombre} #{juan.apellido})"
puts ""

# ── Helpers ──

def upsert_paquete(tracking:, cliente:, tipo_envio:, estado:, peso:, descripcion:, proveedor:, dias:, digitador:)
  p = Paquete.find_by(tracking: tracking)
  attrs = {
    cliente: cliente,
    tipo_envio: tipo_envio,
    estado: estado,
    peso: peso,
    descripcion: descripcion,
    proveedor: proveedor,
    fecha_recibido_miami: dias.days.ago
  }

  if p
    p.update!(attrs)
    p
  else
    Paquete.create!(
      attrs.merge(
        tracking: tracking,
        cantidad_productos: 1,
        cantidad_paquetes: 1,
        user: digitador
      )
    )
  end
end

def upsert_pa_con_paquete(cliente:, tipo_envio:, consolidado:, numero_doc:, titulo:,
                          paquete_tracking:, paquete_desc:, paquete_estado:, paquete_peso:,
                          paquete_proveedor:, dias:, digitador:)
  pa = PreAlerta.find_or_create_by!(numero_documento: numero_doc) do |x|
    x.cliente = cliente
    x.tipo_envio = tipo_envio
    x.con_reempaque = consolidado
    x.consolidado = consolidado
    x.titulo = titulo
    x.creado_por_tipo = "cliente"
    x.creado_por_id = cliente.id
  end
  pa.update!(consolidado: consolidado, finalizado: false, tipo_envio: tipo_envio)

  paquete = upsert_paquete(
    tracking: paquete_tracking,
    cliente: cliente,
    tipo_envio: tipo_envio,
    estado: paquete_estado,
    peso: paquete_peso,
    descripcion: paquete_desc,
    proveedor: paquete_proveedor,
    dias: dias,
    digitador: digitador
  )

  pap = PreAlertaPaquete.find_or_create_by!(tracking: paquete_tracking, pre_alerta: pa) do |x|
    x.descripcion = paquete_desc
    x.fecha = dias.days.ago.to_date
  end
  pap.update!(paquete: paquete)

  pa
end

# ── 1) Paquetes sueltos (sin PAP) por cada tipo consolidable ──
puts "▸ Paquetes sueltos (sin vincular):"

sueltos = [
  # EXPRESS
  { tracking: "DEMO-EXP-S001", tipo: :express, desc: "Laptop Dell XPS 13",      estado: "recibido_miami",   peso: 4.5, prov: "Best Buy", dias: 1 },
  { tracking: "DEMO-EXP-S002", tipo: :express, desc: "Apple Watch Series 9",    estado: "empacado",         peso: 0.5, prov: "Apple",    dias: 2 },
  # CER
  { tracking: "DEMO-CER-S001", tipo: :cer,     desc: "iPhone 15 Pro",           estado: "recibido_miami",   peso: 1.5, prov: "Amazon",   dias: 1 },
  { tracking: "DEMO-CER-S002", tipo: :cer,     desc: "Tenis Jordan Retro",      estado: "empacado",         peso: 3.2, prov: "Nike",     dias: 3 },
  { tracking: "DEMO-CER-S003", tipo: :cer,     desc: "Audifonos Sony WH",       estado: "enviado_honduras", peso: 0.8, prov: "Amazon",   dias: 5 },
  # CEM
  { tracking: "DEMO-CEM-S001", tipo: :cem,     desc: "Mueble Ikea",             estado: "recibido_miami",   peso: 25.0, prov: "Ikea",    dias: 2 },
  { tracking: "DEMO-CEM-S002", tipo: :cem,     desc: "Colchon Queen",           estado: "empacado",         peso: 35.0, prov: "Costco",  dias: 4 }
]

sueltos.each do |data|
  p = Paquete.find_by(tracking: data[:tracking])
  action = p ? "↻" : "✓"
  upsert_paquete(
    tracking: data[:tracking], cliente: juan, tipo_envio: TIPOS[data[:tipo]],
    estado: data[:estado], peso: data[:peso], descripcion: data[:desc],
    proveedor: data[:prov], dias: data[:dias], digitador: digitador
  )
  puts "  #{action} #{data[:tracking]} (#{TIPOS[data[:tipo]].nombre}, #{data[:estado]})"
end

# ── 2) PAs consolidando + paquetes vinculados por tipo consolidable ──
puts ""
puts "▸ PAs consolidando con paquetes vinculados:"

pas_consolidando = [
  { tipo: :express, numero: "PA-DEMO-EXP1", titulo: "EXPRESS - Gadgets urgentes",
    pq_tracking: "DEMO-EXP-V001", pq_desc: "iPad Pro 12.9\"",      pq_estado: "recibido_miami",   pq_peso: 2.0, prov: "Apple",   dias: 1 },
  { tipo: :cer,     numero: "PA-DEMO-CER1", titulo: "CER - Productos Amazon",
    pq_tracking: "DEMO-CER-V001", pq_desc: "Smart TV Samsung 55\"", pq_estado: "recibido_miami",   pq_peso: 2.5, prov: "Best Buy", dias: 2 },
  { tipo: :cer,     numero: "PA-DEMO-CER2", titulo: "CER - Pedido Ebay",
    pq_tracking: "DEMO-CER-V002", pq_desc: "Xbox Series X",        pq_estado: "empacado",         pq_peso: 2.5, prov: "Ebay",    dias: 4 },
  { tipo: :cem,     numero: "PA-DEMO-CEM1", titulo: "CEM - Muebles consolidados",
    pq_tracking: "DEMO-CEM-V001", pq_desc: "Sofa 3 plazas",         pq_estado: "recibido_miami",   pq_peso: 45.0, prov: "Wayfair", dias: 3 }
]

pas_consolidando.each do |data|
  pa = PreAlerta.find_by(numero_documento: data[:numero])
  action = pa ? "↻" : "✓"
  upsert_pa_con_paquete(
    cliente: juan, tipo_envio: TIPOS[data[:tipo]], consolidado: true,
    numero_doc: data[:numero], titulo: data[:titulo],
    paquete_tracking: data[:pq_tracking], paquete_desc: data[:pq_desc],
    paquete_estado: data[:pq_estado], paquete_peso: data[:pq_peso],
    paquete_proveedor: data[:prov], dias: data[:dias], digitador: digitador
  )
  puts "  #{action} #{data[:numero]} (#{TIPOS[data[:tipo]].nombre}) → #{data[:pq_tracking]} (#{data[:pq_estado]})"
end

# ── 3) PAs single_package (CKA/CKM) con paquete vinculado ──
# Para verificar bloqueo "no se puede jalar paquete desde CKA/CKM"
# El paquete vinculado tiene tipo_envio=CER/CEM (el target de una pull) para que pase el filtro
# de same-tipo al ver desde una PA CER/CEM, pero su PAP apunta a un CKA/CKM → debe bloquearse
puts ""
puts "▸ PAs single_package (CKA/CKM) con paquete vinculado (verifican bloqueo):"

single_package = [
  { tipo: :cka, numero: "PA-DEMO-CKA", titulo: "CKA - Caja grande aerea",
    pq_tracking: "DEMO-CKA-V001", pq_desc: "Caja con productos aereos",
    pq_tipo_envio: :cer, pq_estado: "recibido_miami", pq_peso: 15.0, prov: "Walmart", dias: 6 },
  { tipo: :ckm, numero: "PA-DEMO-CKM", titulo: "CKM - Caja grande maritima",
    pq_tracking: "DEMO-CKM-V001", pq_desc: "Caja con productos maritimos",
    pq_tipo_envio: :cem, pq_estado: "recibido_miami", pq_peso: 40.0, prov: "Costco", dias: 7 }
]

single_package.each do |data|
  pa = PreAlerta.find_by(numero_documento: data[:numero])
  action = pa ? "↻" : "✓"
  pa = PreAlerta.find_or_create_by!(numero_documento: data[:numero]) do |x|
    x.cliente = juan
    x.tipo_envio = TIPOS[data[:tipo]]
    x.con_reempaque = false
    x.consolidado = false
    x.titulo = data[:titulo]
    x.creado_por_tipo = "cliente"
    x.creado_por_id = juan.id
  end
  pa.update!(tipo_envio: TIPOS[data[:tipo]])

  paquete = upsert_paquete(
    tracking: data[:pq_tracking], cliente: juan, tipo_envio: TIPOS[data[:pq_tipo_envio]],
    estado: data[:pq_estado], peso: data[:pq_peso], descripcion: data[:pq_desc],
    proveedor: data[:prov], dias: data[:dias], digitador: digitador
  )

  pap = PreAlertaPaquete.find_or_create_by!(tracking: data[:pq_tracking], pre_alerta: pa) do |x|
    x.descripcion = data[:pq_desc]
    x.fecha = data[:dias].days.ago.to_date
  end
  pap.update!(paquete: paquete)

  puts "  #{action} #{data[:numero]} (#{TIPOS[data[:tipo]].nombre}) → #{data[:pq_tracking]} (#{TIPOS[data[:pq_tipo_envio]].nombre}, bloqueado para pull)"
end

puts ""
puts "═══ Listo ═══"
puts ""
puts "Resumen por tipo de envio:"
puts "  EXPRESS: 2 sueltos + 1 PA consolidando (PA-DEMO-EXP1 con DEMO-EXP-V001)"
puts "  CER:     3 sueltos + 2 PAs consolidando (PA-DEMO-CER1/CER2)"
puts "  CEM:     2 sueltos + 1 PA consolidando (PA-DEMO-CEM1 con DEMO-CEM-V001)"
puts "  CKA:     1 PA con paquete CER vinculado (PA-DEMO-CKA)  → NO debe aparecer en pulls"
puts "  CKM:     1 PA con paquete CEM vinculado (PA-DEMO-CKM)  → NO debe aparecer en pulls"
puts ""
puts "Para probar:"
puts "  1. Login como Juan (CEC-001)"
puts "  2. Abre /cuenta/pre_alertas/<id de una PA consolidando>/edit"
puts "  3. Click 'Buscar Paquetes' → ves solo candidatos con MISMO tipo_envio"
puts "     y el pill indigo muestra CER/CEM/EXPRESS"
puts "  4. Abre una PA CKA o CKM → no hay boton 'Buscar Paquetes' (single_package)"
