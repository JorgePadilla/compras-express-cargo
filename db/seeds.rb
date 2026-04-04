puts "Seeding database..."

# ── Admin user ──
User.find_or_create_by!(email_address: "admin@comprasexpresscargo.com") do |u|
  u.nombre = "Administrador"
  u.password = "changeme123"
  u.rol = "admin"
  u.ubicacion = "honduras"
end
puts "  ✓ Admin user"

# ── Tipos de envio ──
[
  { nombre: "AEREO", codigo: "aereo" },
  { nombre: "AEREO EXPRESS", codigo: "aereo-express" },
  { nombre: "CKM MARITIMO", codigo: "ckm-maritimo" },
  { nombre: "CKA ESTANDARD", codigo: "cka-estandard" }
].each do |attrs|
  TipoEnvio.find_or_create_by!(nombre: attrs[:nombre]) do |t|
    t.codigo = attrs[:codigo]
    t.activo = true
  end
end
puts "  ✓ #{TipoEnvio.count} tipos de envio"

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
  # Demo users per role
  [
    { nombre: "Supervisor Miami", email: "supervisor@cec.com", rol: "supervisor_miami", ubicacion: "miami" },
    { nombre: "Digitador Miami", email: "digitador@cec.com", rol: "digitador_miami", ubicacion: "miami" },
    { nombre: "Supervisor Caja", email: "sup_caja@cec.com", rol: "supervisor_caja", ubicacion: "honduras" },
    { nombre: "Cajero Honduras", email: "cajero@cec.com", rol: "cajero", ubicacion: "honduras" },
    { nombre: "SAC", email: "sac@cec.com", rol: "sac", ubicacion: "honduras" },
    { nombre: "Entrega", email: "entrega@cec.com", rol: "entrega_despacho", ubicacion: "honduras" }
  ].each do |attrs|
    User.find_or_create_by!(email_address: attrs[:email]) do |u|
      u.nombre = attrs[:nombre]
      u.password = "Demo123!"
      u.rol = attrs[:rol]
      u.ubicacion = attrs[:ubicacion]
    end
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
    Cliente.find_or_create_by!(nombre: attrs[:nombre], apellido: attrs[:apellido]) do |c|
      c.assign_attributes(attrs.except(:nombre, :apellido))
    end
  end
  puts "  ✓ #{Cliente.count} clientes"

  # Demo paquetes
  digitador = User.find_by!(email_address: "digitador@cec.com")
  aereo = TipoEnvio.find_by!(nombre: "AEREO")
  maritimo = TipoEnvio.find_by!(nombre: "CKM MARITIMO")
  clientes = Cliente.all.to_a
  carriers = %w[FedEx DHL UPS USPS Amazon]
  proveedores = %w[Amazon eBay Shein Walmart Target Nike Zara]
  estados = %w[recibido etiquetado etiquetado etiquetado etiquetado en_manifiesto enviado en_bodega_hn pre_facturado entregado]

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
      pre_factura: i % 7 == 0,
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
    m.tipo_envio = "AEREO"
    m.user = digitador
  end

  manifiesto_enviado = Manifiesto.find_or_create_by!(numero: "MA-000002") do |m|
    m.empresa_manifiesto = empresa
    m.tipo_envio = "AEREO"
    m.estado = "enviado"
    m.fecha_enviado = 3.days.ago
    m.user = digitador
  end

  # Assign some packages to manifests
  etiquetados = Paquete.where(estado: "etiquetado", manifiesto_id: nil).limit(3)
  etiquetados.each do |p|
    p.update!(manifiesto: manifiesto_creado, estado: "en_manifiesto")
  end
  manifiesto_creado.recalculate_totals!

  enviados = Paquete.where(estado: "enviado", manifiesto_id: nil).limit(2)
  enviados.each do |p|
    p.update!(manifiesto: manifiesto_enviado)
  end
  manifiesto_enviado.recalculate_totals!

  puts "  ✓ #{Manifiesto.count} manifiestos"
end

puts "Seed completed!"
