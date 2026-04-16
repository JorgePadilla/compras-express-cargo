# Demo data for the "Buscar Paquetes" modal on /cuenta/pre_alertas/:id/edit
#
# Creates, for the default cliente (Juan / CEC-001):
#   - 3 "paquetes sueltos" (no PAP linking) with tipo_envio=CER, estado=recibido_miami/empacado/enviado_honduras
#   - 2 other CER consolidando pre-alertas, each with 1 PAP linked to a CER paquete in a movable estado
#   - 1 CKA pre-alerta + linked CER paquete (to verify blocking "from CKA/CKM" rule)
#
# Run with:
#   bin/rails runner db/seeds/buscar_paquetes_demo.rb
#
# Idempotent: safe to re-run. Matches by tracking.

require_relative "../../config/environment" unless defined?(Rails)

# Cliente destino: Juan Perez (creado por seeds sample data) o el primero con codigo CEC-001
juan = Cliente.find_by(nombre: "Juan", apellido: "Perez") || Cliente.find_by(codigo: "CEC-001")
unless juan
  puts "⚠️  No se encontro cliente Juan Perez ni CEC-001 — corre primero `SEED_SAMPLE_DATA=1 bin/rails db:seed`"
  exit 1
end

cer  = TipoEnvio.find_by!(codigo: "cer")
cka  = TipoEnvio.find_by!(codigo: "cka")
digitador = User.where(rol: %w[digitador_miami supervisor_miami]).first || User.first

puts "═══ Buscar Paquetes demo seed ═══"
puts "Cliente: #{juan.codigo} (#{juan.nombre} #{juan.apellido})"
puts "Tipo envio: CER (id=#{cer.id})"
puts ""

# ── 1) Paquetes sueltos para Juan (sin PAP) ──
sueltos = [
  { tracking: "DEMO-SUELTO-001", descripcion: "iPhone 15 Pro",       estado: "recibido_miami",    peso: 1.5, dias: 1 },
  { tracking: "DEMO-SUELTO-002", descripcion: "Tenis Jordan Retro",  estado: "empacado",          peso: 3.2, dias: 3 },
  { tracking: "DEMO-SUELTO-003", descripcion: "Audifonos Sony WH",   estado: "enviado_honduras", peso: 0.8, dias: 5 }
]

sueltos.each do |data|
  p = Paquete.find_by(tracking: data[:tracking])
  if p
    p.update!(
      cliente: juan, tipo_envio: cer, estado: data[:estado],
      peso: data[:peso], descripcion: data[:descripcion],
      proveedor: "Amazon", fecha_recibido_miami: data[:dias].days.ago
    )
    puts "  ↻ Paquete suelto #{data[:tracking]} actualizado (#{data[:estado]})"
  else
    Paquete.create!(
      tracking: data[:tracking],
      cliente: juan,
      tipo_envio: cer,
      estado: data[:estado],
      peso: data[:peso],
      cantidad_productos: 1,
      cantidad_paquetes: 1,
      descripcion: data[:descripcion],
      proveedor: "Amazon",
      fecha_recibido_miami: data[:dias].days.ago,
      user: digitador
    )
    puts "  ✓ Paquete suelto #{data[:tracking]} creado (#{data[:estado]})"
  end
end

# ── 2) Dos pre-alertas CER consolidando con paquetes vinculados ──
def upsert_pa_con_paquete_vinculado(juan, cer, digitador, numero_doc:, titulo:, paquete_tracking:, paquete_desc:, paquete_estado:, dias:)
  pa = PreAlerta.find_or_create_by!(numero_documento: numero_doc) do |x|
    x.cliente = juan
    x.tipo_envio = cer
    x.con_reempaque = true
    x.consolidado = true
    x.titulo = titulo
    x.creado_por_tipo = "cliente"
    x.creado_por_id = juan.id
  end
  pa.update!(consolidado: true, finalizado: false) # ensure state

  paquete = Paquete.find_by(tracking: paquete_tracking)
  if paquete
    paquete.update!(
      cliente: juan, tipo_envio: cer, estado: paquete_estado,
      descripcion: paquete_desc, fecha_recibido_miami: dias.days.ago
    )
  else
    paquete = Paquete.create!(
      tracking: paquete_tracking,
      cliente: juan,
      tipo_envio: cer,
      estado: paquete_estado,
      peso: 2.5,
      cantidad_productos: 1,
      cantidad_paquetes: 1,
      descripcion: paquete_desc,
      proveedor: "Best Buy",
      fecha_recibido_miami: dias.days.ago,
      user: digitador
    )
  end

  pap = PreAlertaPaquete.find_or_create_by!(tracking: paquete_tracking, pre_alerta: pa) do |x|
    x.descripcion = paquete_desc
    x.fecha = dias.days.ago.to_date
  end
  pap.update!(paquete: paquete)

  pa
end

upsert_pa_con_paquete_vinculado(
  juan, cer, digitador,
  numero_doc: "PA-DEMO-CER1",
  titulo: "Consolidando - Productos Amazon",
  paquete_tracking: "DEMO-VINC-001",
  paquete_desc: "Smart TV Samsung 55\"",
  paquete_estado: "recibido_miami",
  dias: 2
)
puts "  ✓ PA-DEMO-CER1 (CER consolidando) con DEMO-VINC-001 (recibido_miami)"

upsert_pa_con_paquete_vinculado(
  juan, cer, digitador,
  numero_doc: "PA-DEMO-CER2",
  titulo: "Consolidando - Pedido Ebay",
  paquete_tracking: "DEMO-VINC-002",
  paquete_desc: "Xbox Series X",
  paquete_estado: "empacado",
  dias: 4
)
puts "  ✓ PA-DEMO-CER2 (CER consolidando) con DEMO-VINC-002 (empacado)"

# ── 3) PA CKA con paquete vinculado — para verificar bloqueo CKA/CKM ──
# El paquete DEBE ser CER para que pase el filtro tipo_envio en candidatos_para_buscar,
# pero debe estar vinculado a una CKA para ejecutar el bloqueo en agregar_paquete.
pa_cka_demo = PreAlerta.find_or_create_by!(numero_documento: "PA-DEMO-CKA") do |x|
  x.cliente = juan
  x.tipo_envio = cka
  x.con_reempaque = false
  x.consolidado = false
  x.titulo = "CKA - Caja grande"
  x.creado_por_tipo = "cliente"
  x.creado_por_id = juan.id
end

paquete_cka = Paquete.find_by(tracking: "DEMO-VINC-CKA")
if paquete_cka
  paquete_cka.update!(
    cliente: juan, tipo_envio: cer, estado: "recibido_miami",
    descripcion: "Caja con productos varios", fecha_recibido_miami: 6.days.ago
  )
else
  paquete_cka = Paquete.create!(
    tracking: "DEMO-VINC-CKA",
    cliente: juan,
    tipo_envio: cer,
    estado: "recibido_miami",
    peso: 15.0,
    cantidad_productos: 5,
    cantidad_paquetes: 1,
    descripcion: "Caja con productos varios",
    proveedor: "Walmart",
    fecha_recibido_miami: 6.days.ago,
    user: digitador
  )
end

pap_cka_demo = PreAlertaPaquete.find_or_create_by!(tracking: "DEMO-VINC-CKA", pre_alerta: pa_cka_demo) do |x|
  x.descripcion = "Caja con productos varios"
  x.fecha = 6.days.ago.to_date
end
pap_cka_demo.update!(paquete: paquete_cka)
puts "  ✓ PA-DEMO-CKA (CKA) con DEMO-VINC-CKA vinculado — debe NO aparecer en modal"

puts ""
puts "═══ Listo ═══"
puts ""
puts "Para probar el modal:"
puts "  1. Ingresa como Juan (CEC-001) → cuenta/pre_alertas"
puts "  2. Abre o crea cualquier pre-alerta CER consolidando"
puts "  3. En la tabla de Paquetes haz click en 'Buscar Paquetes'"
puts "  4. Deberias ver:"
puts "     - 3 sueltos (Suelto en bodega, verde):"
puts "       DEMO-SUELTO-001/002/003"
puts "     - 2 vinculados (De PA-DEMO-CER1/PA-DEMO-CER2, ambar):"
puts "       DEMO-VINC-001 y DEMO-VINC-002"
puts "  5. DEMO-VINC-CKA NO debe aparecer (vinculado a CKA)."
