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
end

puts "Seed completed!"
