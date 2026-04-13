puts "Seeding database..."

# ── Admin user ──
User.find_or_create_by!(email_address: "admin@comprasexpresscargo.com") do |u|
  u.nombre = "Administrador"
  u.password = "changeme123"
  u.rol = "admin"
  u.ubicacion = "honduras"
end
puts "  ✓ Admin user"

# ── Tipos de envio (v4.0 — ver docs/approved/pre_alerta_v4.docx) ──
[
  { nombre: "EXPRESS", codigo: "express", con_reempaque: true,  consolidable: true,
    precio_libra: 8.00, modalidad: "aereo",    sla: "3-7 dias habiles",   max_paquetes_por_accion: nil },
  { nombre: "CER",     codigo: "cer",     con_reempaque: true,  consolidable: true,
    precio_libra: 4.50, modalidad: "aereo",    sla: "6-10 dias habiles",  max_paquetes_por_accion: nil },
  { nombre: "CEM",     codigo: "cem",     con_reempaque: true,  consolidable: true,
    precio_libra: 2.50, modalidad: "maritimo", sla: "14-17 dias habiles", max_paquetes_por_accion: nil },
  { nombre: "CKA",     codigo: "cka",     con_reempaque: false, consolidable: false,
    precio_libra: 4.00, modalidad: "aereo",    sla: "6-10 dias habiles",  max_paquetes_por_accion: 1 },
  { nombre: "CKM",     codigo: "ckm",     con_reempaque: false, consolidable: false,
    precio_libra: 1.50, modalidad: "maritimo", sla: "14-17 dias habiles", max_paquetes_por_accion: 1 }
].each do |attrs|
  te = TipoEnvio.find_or_initialize_by(codigo: attrs[:codigo])
  te.assign_attributes(attrs)
  te.activo = true
  te.save!
end

# Eliminar legacy tipos de envio (safety-net para staging/production)
TipoEnvio.where(codigo: %w[aereo aereo-express ckm-maritimo cka-estandard cer-legacy cem-legacy]).destroy_all

puts "  ✓ #{TipoEnvio.activos.count} tipos de envio v4"

# ── Carriers ──
[
  { nombre: "FedEx", tipo: "aereo" },
  { nombre: "DHL", tipo: "aereo" },
  { nombre: "UPS", tipo: "aereo" },
  { nombre: "USPS", tipo: "aereo" },
  { nombre: "Amazon", tipo: "aereo" }
].each do |attrs|
  Carrier.find_or_create_by!(nombre: attrs[:nombre]) do |c|
    c.tipo = attrs[:tipo]
    c.activo = true
  end
end
puts "  ✓ #{Carrier.count} carriers"

# ── Empresas de manifiesto ──
%w[PRONTO\ CARGO SERCARGO GENESIS].each do |nombre|
  EmpresaManifiesto.find_or_create_by!(nombre: nombre) { |e| e.activo = true }
end
puts "  ✓ #{EmpresaManifiesto.count} empresas de manifiesto"

# ── Categorias de precio ──
[
  { nombre: "Regular", precio_libra_aereo: 3.50, precio_libra_maritimo: 1.50, precio_volumen: 0.008 },
  { nombre: "VIP", precio_libra_aereo: 3.00, precio_libra_maritimo: 1.25, precio_volumen: 0.007 },
  { nombre: "Mayorista", precio_libra_aereo: 2.50, precio_libra_maritimo: 1.00, precio_volumen: 0.006 }
].each do |attrs|
  CategoriaPrecio.find_or_create_by!(nombre: attrs[:nombre]) do |cp|
    cp.precio_libra_aereo = attrs[:precio_libra_aereo]
    cp.precio_libra_maritimo = attrs[:precio_libra_maritimo]
    cp.precio_volumen = attrs[:precio_volumen]
  end
end
puts "  ✓ #{CategoriaPrecio.count} categorias de precio"

# ── Configuraciones ──
{
  "tasa_cambio" => { valor: "24.85", tipo: "decimal", categoria: "general" },
  "empresa_nombre" => { valor: "Compras Express Cargo", tipo: "string", categoria: "general" },
  "empresa_email" => { valor: "info@comprasexpresscargo.com", tipo: "string", categoria: "general" },
  "iva_porcentaje" => { valor: "15", tipo: "decimal", categoria: "facturacion" }
}.each do |clave, attrs|
  Configuracion.find_or_create_by!(clave: clave) do |c|
    c.valor = attrs[:valor]
    c.tipo = attrs[:tipo]
    c.categoria = attrs[:categoria]
  end
end
puts "  ✓ #{Configuracion.count} configuraciones"

# ── Sample data (dev/staging only) ──
if Rails.env.development? || ENV["SEED_SAMPLE_DATA"]
  # Demo users per role — always reset on re-seed so documented credentials work
  [
    { nombre: "Supervisor Miami", email: "supervisor@cec.com", rol: "supervisor_miami", ubicacion: "miami" },
    { nombre: "Digitador Miami", email: "digitador@cec.com", rol: "digitador_miami", ubicacion: "miami" },
    { nombre: "Supervisor Caja", email: "sup_caja@cec.com", rol: "supervisor_caja", ubicacion: "honduras" },
    { nombre: "Cajero Honduras", email: "cajero@cec.com", rol: "cajero", ubicacion: "honduras" },
    { nombre: "SAC", email: "sac@cec.com", rol: "sac", ubicacion: "honduras" },
    { nombre: "Entrega", email: "entrega@cec.com", rol: "entrega_despacho", ubicacion: "honduras" }
  ].each do |attrs|
    user = User.find_or_initialize_by(email_address: attrs[:email])
    user.nombre = attrs[:nombre]
    user.rol = attrs[:rol]
    user.ubicacion = attrs[:ubicacion]
    user.password = "Demo123!"
    user.save!
  end
  puts "  ✓ #{User.count} users total (including demo)"

  # Demo clients
  regular = CategoriaPrecio.find_by!(nombre: "Regular")
  vip = CategoriaPrecio.find_by!(nombre: "VIP")
  [
    { nombre: "Juan", apellido: "Perez", identidad: "0801199012345", email: "juan.perez@gmail.com",
      telefono: "99887766", telefono_whatsapp: "99887766", direccion: "Col. Kennedy, Tegucigalpa",
      ciudad: "Tegucigalpa", departamento: "Francisco Morazan", categoria_precio: regular },
    { nombre: "Maria", apellido: "Lopez", email: "maria.lopez@hotmail.com",
      telefono: "99112233", ciudad: "San Pedro Sula", departamento: "Cortes", categoria_precio: vip },
    { nombre: "Carlos", apellido: "Reyes", email: "carlos.reyes@yahoo.com",
      telefono: "98765432", ciudad: "La Ceiba", departamento: "Atlantida", categoria_precio: regular },
    { nombre: "Ana", apellido: "Martinez", email: "ana.mtz@gmail.com",
      telefono: "97654321", telefono_whatsapp: "97654321", direccion: "Bo. El Centro",
      ciudad: "Comayagua", departamento: "Comayagua", categoria_precio: regular },
    { nombre: "Roberto", apellido: "Hernandez", email: "roberto.h@gmail.com",
      telefono: "96543210", ciudad: "Tegucigalpa", departamento: "Francisco Morazan", categoria_precio: vip },
    { nombre: "Sofia", apellido: "Garcia", email: "sofia.g@outlook.com",
      telefono: "95432109", ciudad: "San Pedro Sula", departamento: "Cortes", categoria_precio: regular },
    { nombre: "Diego", apellido: "Flores", email: "diego.flores@gmail.com",
      telefono: "94321098", ciudad: "Choluteca", departamento: "Choluteca" },
    { nombre: "Lucia", apellido: "Rivera", email: "lucia.r@gmail.com",
      telefono: "93210987", ciudad: "Tegucigalpa", departamento: "Francisco Morazan", categoria_precio: regular },
    { nombre: "Pedro", apellido: "Mejia", email: "pedro.mejia@yahoo.com",
      telefono: "92109876", ciudad: "Danli", departamento: "El Paraiso" },
    { nombre: "Carmen", apellido: "Santos", email: "carmen.s@hotmail.com",
      telefono: "91098765", ciudad: "Siguatepeque", departamento: "Comayagua", categoria_precio: vip }
  ].each do |attrs|
    cliente = Cliente.find_or_initialize_by(nombre: attrs[:nombre], apellido: attrs[:apellido])
    cliente.assign_attributes(attrs.except(:nombre, :apellido))
    cliente.password = "Cliente123!"
    cliente.save!
  end
  # Safety net: any other client without a password gets the demo password
  Cliente.where(password_digest: nil).find_each { |c| c.update!(password: "Cliente123!") }
  puts "  ✓ #{Cliente.count} clientes"

  # Demo paquetes
  digitador = User.find_by!(email_address: "digitador@cec.com")
  aereo = TipoEnvio.find_by!(codigo: "cer")
  maritimo = TipoEnvio.find_by!(codigo: "cem")
  clientes = Cliente.all.to_a
  carriers = %w[FedEx DHL UPS USPS Amazon]
  proveedores = %w[Amazon eBay Shein Walmart Target Nike Zara]
  estados = %w[recibido_miami empacado empacado empacado empacado empacado enviado_honduras disponible_entrega pre_facturado entregado]

  20.times do |i|
    tracking = "1Z999TEST#{(i + 1).to_s.rjust(6, '0')}"
    next if Paquete.exists?(tracking: tracking)

    estado = estados[i % estados.length]
    peso = rand(1.0..50.0).round(2)
    alto = rand(5.0..30.0).round(2)
    largo = rand(5.0..40.0).round(2)
    ancho = rand(5.0..30.0).round(2)

    Paquete.create!(
      tracking: tracking,
      cliente: clientes[i % clientes.length],
      tipo_envio: i.even? ? aereo : maritimo,
      estado: estado,
      peso: peso,
      alto: alto, largo: largo, ancho: ancho,
      cantidad_productos: rand(1..5),
      cantidad_paquetes: 1,
      descripcion: ["Ropa variada", "Zapatos Nike", "Electronica", "Suplementos", "Libros", "Juguetes", "Cosmeticos", "Accesorios"][i % 8],
      proveedor: proveedores[i % proveedores.length],
      expedido_por: carriers[i % carriers.length],
      pre_alerta: i % 5 == 0,
      solicito_cambio_servicio: i == 3,
      retener_miami: i == 7,
      user: digitador,
      fecha_recibido_miami: rand(1..30).days.ago
    )
  end
  puts "  ✓ #{Paquete.count} paquetes"

  # Demo manifiestos
  empresa = EmpresaManifiesto.find_by!(nombre: "PRONTO CARGO")

  manifiesto_creado = Manifiesto.find_or_create_by!(numero: "MA-000001") do |m|
    m.empresa_manifiesto = empresa
    m.tipo_envio = "CER"
    m.user = digitador
  end

  manifiesto_enviado = Manifiesto.find_or_create_by!(numero: "MA-000002") do |m|
    m.empresa_manifiesto = empresa
    m.tipo_envio = "CER"
    m.estado = "enviado"
    m.fecha_enviado = 3.days.ago
    m.user = digitador
  end

  # Assign some packages to manifests
  empacados = Paquete.where(estado: "empacado", manifiesto_id: nil).limit(3)
  empacados.each do |p|
    p.update!(manifiesto: manifiesto_creado)
  end
  manifiesto_creado.recalculate_totals!

  enviados_hn = Paquete.where(estado: "enviado_honduras", manifiesto_id: nil).limit(2)
  enviados_hn.each do |p|
    p.update!(manifiesto: manifiesto_enviado)
  end
  manifiesto_enviado.recalculate_totals!

  puts "  ✓ #{Manifiesto.count} manifiestos"

  # Demo pre-alertas
  juan = Cliente.find_by!(nombre: "Juan", apellido: "Perez")
  maria = Cliente.find_by!(nombre: "Maria", apellido: "Lopez")

  pa1 = PreAlerta.find_or_create_by!(numero_documento: "PA-000001") do |pa|
    pa.cliente = juan
    pa.tipo_envio = aereo
    pa.con_reempaque = true
    pa.consolidado = false
    pa.creado_por_tipo = "cliente"
    pa.creado_por_id = juan.id
  end
  PreAlertaPaquete.find_or_create_by!(pre_alerta: pa1, tracking: "1Z999DEMO000001") do |pap|
    pap.descripcion = "Zapatos Nike Air Max"
    pap.fecha = 2.days.ago.to_date
  end
  PreAlertaPaquete.find_or_create_by!(pre_alerta: pa1, tracking: "1Z999DEMO000002") do |pap|
    pap.descripcion = "Ropa variada Amazon"
    pap.fecha = 1.day.ago.to_date
  end

  pa2 = PreAlerta.find_or_create_by!(numero_documento: "PA-000002") do |pa|
    pa.cliente = maria
    pa.tipo_envio = maritimo
    pa.con_reempaque = false
    pa.consolidado = true
    pa.estado = "recibido"
    pa.notificado = true
    pa.creado_por_tipo = "cliente"
    pa.creado_por_id = maria.id
  end
  PreAlertaPaquete.find_or_create_by!(pre_alerta: pa2, tracking: "9400DEMO000001") do |pap|
    pap.descripcion = "Cosmeticos Sephora"
    pap.fecha = 5.days.ago.to_date
  end

  pa3 = PreAlerta.find_or_create_by!(numero_documento: "PA-000003") do |pa|
    pa.cliente = juan
    pa.tipo_envio = aereo
    pa.con_reempaque = false
    pa.consolidado = false
    pa.creado_por_tipo = "cliente"
    pa.creado_por_id = juan.id
  end
  PreAlertaPaquete.find_or_create_by!(pre_alerta: pa3, tracking: "AMZN-DEMO-001") do |pap|
    pap.descripcion = "Suplementos vitaminicos"
    pap.fecha = Date.current
  end

  puts "  ✓ #{PreAlerta.count} pre-alertas"
end

# ── Empresa singleton (datos fiscales para PDFs y mailers) ──
Empresa.instance.update!(
  nombre: "Compras Express Cargo",
  rtn: "08011998123456",
  telefono: "+504 2550-0000",
  email_contacto: "info@comprasexpresscargo.com",
  direccion: "Boulevard del Este, San Pedro Sula",
  ciudad: "San Pedro Sula",
  pais: "Honduras",
  moneda_default: "LPS",
  isv_rate: BigDecimal("0.15"),
  sitio_web: "https://comprasexpresscargo.com",
  terminos_factura: "Esta factura es valida como comprobante fiscal. Gracias por preferir Compras Express Cargo."
)
puts "  ✓ Empresa singleton"

puts "Seed completed!"
