puts "Seeding database..."

# ── Admin user ──
User.find_or_create_by!(email_address: "admin@comprasexpresscargo.com") do |u|
  u.nombre = "Administrador"
  u.password = "changeme123"
  u.rol = "admin"
  u.ubicacion = "honduras"
end
puts "  ✓ Admin user"

# ── Sucursales iniciales ──
[
  { codigo: "MIA", codigo_ep: "SMI", nombre: "Miami",      pais: "USA",      ubicacion: "miami",    codigo_recepcion_prefix: "RMI" },
  { codigo: "SPS", codigo_ep: "SZR", nombre: "Zeron SPS",  pais: "Honduras", ubicacion: "honduras", codigo_recepcion_prefix: "RZE" },
  { codigo: "TGU", codigo_ep: "SHU", nombre: "Humuya TGU", pais: "Honduras", ubicacion: "honduras", codigo_recepcion_prefix: "RHU" },
  { codigo: "SAM", codigo_ep: "SSM", nombre: "San Manuel", pais: "Honduras", ubicacion: "honduras", codigo_recepcion_prefix: "RSM" }
].each do |attrs|
  Sucursal.find_or_create_by!(codigo: attrs[:codigo]) do |s|
    s.assign_attributes(attrs)
  end
  # Backfill defensivo para sucursales que ya existían sin codigo_ep.
  s = Sucursal.find_by(codigo: attrs[:codigo])
  s.update_column(:codigo_ep, attrs[:codigo_ep]) if s && s.codigo_ep.blank?
end
puts "  ✓ #{Sucursal.count} sucursales"

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

# Marcar legacy tipos de envio como inactivos (no borrar — pueden estar
# referenciados por paquetes existentes y `destroy_all` violaría la FK).
# Quedan ocultos del listado activo pero conservan integridad referencial.
TipoEnvio.where(codigo: %w[aereo aereo-express ckm-maritimo cka-estandard cer-legacy cem-legacy])
         .update_all(activo: false)

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

# ── Suppliers (PR-5c.5) ──
puts "Seeding suppliers..."
[
  { codigo: "AMZN",     nombre: "AMAZON LLC",      tipo: "comercio",         city: "Seattle",     state: "WA", country: "USA" },
  { codigo: "EBAY",     nombre: "EBAY INC",        tipo: "comercio",         city: "San Jose",    state: "CA", country: "USA" },
  { codigo: "WMT",      nombre: "WALMART",         tipo: "comercio",         city: "Bentonville", state: "AR", country: "USA" },
  { codigo: "SAMS",     nombre: "SAMS CLUB",       tipo: "comercio",         city: "Bentonville", state: "AR", country: "USA" },
  { codigo: "TGT",      nombre: "TARGET",          tipo: "comercio",         city: "Minneapolis", state: "MN", country: "USA" },
  { codigo: "EP",       nombre: "ENTREGA PERSONAL", tipo: "entrega_personal", country: "USA" },
  { codigo: "OTROS",    nombre: "OTROS",           tipo: "otros",            country: "USA" }
].each_with_index do |attrs, idx|
  Supplier.find_or_create_by!(codigo: attrs[:codigo]) do |s|
    s.nombre        = attrs[:nombre]
    s.tipo          = attrs[:tipo]
    s.city          = attrs[:city]
    s.state         = attrs[:state]
    s.country       = attrs[:country]
    s.position      = idx
  end
end
puts "  ✓ #{Supplier.count} suppliers"

# ── Terms (T&C bilingues, PR-5c.5) ──
puts "Seeding terms..."
TERMS_ES = <<~ES.strip.freeze
  1. La empresa transportará la mercancía descrita en este recibo bajo las condiciones aquí establecidas.
  2. El cliente declara que la información del contenido es verídica. La empresa no se responsabiliza por declaraciones falsas o incompletas.
  3. Los pesos y dimensiones son verificados al recibir; la facturación final usa el peso facturable mayor entre real y volumétrico.
  4. La mercancía no reclamada en un plazo de 30 días naturales se considerará abandonada.
  5. La empresa no se hace responsable de daños por embalaje insuficiente, mercancía prohibida o contenido perecedero.
  6. La firma o aceptación electrónica de este recibo constituye conformidad con los términos.
ES

TERMS_EN = <<~EN.strip.freeze
  1. The carrier shall transport the merchandise described herein under the conditions set forth.
  2. The customer warrants that the content information is true and accurate. Carrier is not liable for false or incomplete declarations.
  3. Weights and dimensions are verified upon receipt; billing uses the chargeable weight (greater of actual and volumetric).
  4. Goods unclaimed within 30 calendar days will be deemed abandoned.
  5. Carrier shall not be liable for damages caused by insufficient packaging, prohibited items, or perishable content.
  6. Signature or electronic acceptance of this receipt constitutes agreement with the terms.
EN

[
  { version: "2026-01", language: "es", body: TERMS_ES },
  { version: "2026-01", language: "en", body: TERMS_EN }
].each do |attrs|
  Term.find_or_create_by!(version: attrs[:version], language: attrs[:language]) do |t|
    t.body           = attrs[:body]
    t.effective_from = Date.new(2026, 1, 1)
  end
end
puts "  ✓ #{Term.count} terms (#{Term.distinct.pluck(:version).join(', ')})"

# ── Sub-Localidades (PR-D1.c) ──
# Bodegas internas / áreas terceras dentro de cada sucursal HND. Yusef
# 2026-04-29: "ZR01 (bodega central), ZR02 (bodega CEM)".
puts "Seeding sub_localidades..."
zeron  = Sucursal.find_by(codigo: "SPS")
humuya = Sucursal.find_by(codigo: "TGU")
[
  { sucursal: zeron,  codigo: "ZR01", nombre: "Zerón Bodega Central",        position: 0 },
  { sucursal: zeron,  codigo: "ZR02", nombre: "Zerón Bodega CEM (Marítimo)", position: 1 },
  { sucursal: humuya, codigo: "HM01", nombre: "Humuya Bodega Central",       position: 0 }
].each do |attrs|
  next if attrs[:sucursal].nil?
  SubLocalidad.find_or_create_by!(sucursal: attrs[:sucursal], codigo: attrs[:codigo]) do |s|
    s.nombre = attrs[:nombre]
    s.position = attrs[:position]
  end
end
puts "  ✓ #{SubLocalidad.count} sub-localidades"

# ── Plantillas Notas al Cliente (PR-D2) ──
puts "Seeding plantillas_notas_cliente..."
[
  { titulo: "Falta declaración de aduana",   texto: "Estimado cliente, para procesar su paquete necesitamos la declaración de aduana firmada. Por favor envíela a info@comprasexpresscargo.com.", position: 0 },
  { titulo: "Pago pendiente",                texto: "Estimado cliente, su paquete está listo en bodega. Para procesar la entrega favor cancelar el saldo pendiente en sucursal o vía transferencia.", position: 1 },
  { titulo: "Confirmar dirección de entrega", texto: "Estimado cliente, necesitamos que confirme la dirección de entrega para programar el reparto. Responda este correo o llame a la sucursal.", position: 2 },
  { titulo: "Paquete listo para retiro",     texto: "Estimado cliente, su paquete está disponible en sucursal. Horario de atención: lunes a viernes 8am-5pm, sábado 8am-1pm.", position: 3 }
].each do |attrs|
  PlantillaNotaCliente.find_or_create_by!(titulo: attrs[:titulo]) do |p|
    p.texto    = attrs[:texto]
    p.position = attrs[:position]
  end
end
puts "  ✓ #{PlantillaNotaCliente.count} plantillas notas al cliente"

# ── Motivos de Retención (PR-D2) ──
puts "Seeding motivos_retencion..."
[
  { nombre: "Paquete dañado",                descripcion: "Llegó con daños visibles", position: 0 },
  { nombre: "Confirmar tipo de envío",       descripcion: "El cliente debe confirmar si va aéreo, marítimo o express", position: 1 },
  { nombre: "Mercancía prohibida",           descripcion: "Contenido no permitido por aduana o por nuestras políticas", position: 2 },
  { nombre: "Falta declaración del cliente", descripcion: "Cliente debe enviar declaración de contenido", position: 3 },
  { nombre: "Contenido perecedero",          descripcion: "Requiere manejo especial o no se acepta", position: 4 },
  { nombre: "Pago pendiente",                descripcion: "Saldo pendiente que bloquea la entrega",       position: 5 }
].each do |attrs|
  MotivoRetencion.find_or_create_by!(nombre: attrs[:nombre]) do |m|
    m.descripcion = attrs[:descripcion]
    m.position    = attrs[:position]
  end
end
puts "  ✓ #{MotivoRetencion.count} motivos de retención"

# ── Proveedores (PR-D3.a) ──
# Yusef 2026-04-30: lista inicial de comercios recurrentes (Walmart,
# Whole Foods, Amazon, eBay, Target, Sams, Costco, etc.). Drivers
# privados (entrega_personal) los agregan los operadores conforme
# aparecen. El `codigo` se autogenera del nombre (ver Proveedor.generar_codigo_desde).
puts "Seeding proveedores..."
[
  { nombre: "Amazon",      tipo: "comercio", position: 0 },
  { nombre: "Walmart",     tipo: "comercio", position: 1 },
  { nombre: "Target",      tipo: "comercio", position: 2 },
  { nombre: "eBay",        tipo: "comercio", position: 3 },
  { nombre: "Sams Club",   tipo: "comercio", position: 4 },
  { nombre: "Costco",      tipo: "comercio", position: 5 },
  { nombre: "Whole Foods", tipo: "comercio", position: 6 }
].each do |attrs|
  Proveedor.find_or_create_by!(nombre: attrs[:nombre]) do |p|
    p.tipo     = attrs[:tipo]
    p.position = attrs[:position]
    p.activo   = true
  end
end
puts "  ✓ #{Proveedor.count} proveedores"

# ── Tarifas de Recolecta (PR-D6.a) ──
# Yusef 2026-05-01: tabla configurable por zona en lugar de tarifa fija.
# Estos seeds son ejemplos razonables — admin los edita en /tarifas_recolecta.
puts "Seeding tarifas de recolecta..."
[
  { zona: "SPS Centro",          monto: 30.00, moneda: "USD", position: 0 },
  { zona: "SPS Periférico",      monto: 35.00, moneda: "USD", position: 1 },
  { zona: "Tegucigalpa Centro",  monto: 35.00, moneda: "USD", position: 2 },
  { zona: "Tegucigalpa Suyapa",  monto: 40.00, moneda: "USD", position: 3 },
  { zona: "La Ceiba",            monto: 50.00, moneda: "USD", position: 4 },
  { zona: "Otra zona / cotizar", monto: 40.00, moneda: "USD", position: 9 }
].each do |attrs|
  TarifaRecolecta.find_or_create_by!(zona: attrs[:zona]) do |t|
    t.assign_attributes(attrs.merge(activo: true))
  end
end
puts "  ✓ #{TarifaRecolecta.count} tarifas de recolecta"

# ── Servicios Extra (PR-D6.a) ──
# Yusef 2026-05-01: catálogo de servicios/productos que se agregan
# automáticamente a la pre-factura cuando el paquete tiene el flag
# correspondiente (cambio de servicio, etc.). Precio incluye ISV.
puts "Seeding servicios extra..."
[
  { codigo: "CAMBIO_SERVICIO", descripcion: "Cambio de servicio (aéreo↔marítimo, con/sin reempaque)",
    costo: 0, precio_venta: 15.00, moneda: "USD", precio_incluye_isv: true, position: 0 },
  { codigo: "PESO_ADICIONAL",  descripcion: "Peso adicional declarado vs medido",
    costo: 0, precio_venta: 0,     moneda: "USD", precio_incluye_isv: true, position: 1 },
  { codigo: "MANEJO_ESPECIAL", descripcion: "Manejo especial (frágil, voluminoso, perecedero)",
    costo: 0, precio_venta: 10.00, moneda: "USD", precio_incluye_isv: true, position: 2 }
].each do |attrs|
  ServicioExtra.find_or_create_by!(codigo: attrs[:codigo]) do |s|
    s.assign_attributes(attrs.merge(activo: true))
  end
end
puts "  ✓ #{ServicioExtra.count} servicios extra"

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

  # Demo data para el modal "Buscar Paquetes" en /cuenta/pre_alertas/:id/edit
  # Crea paquetes sueltos + 2 PAs CER consolidando + 1 PA CKA (para verificar bloqueo)
  load Rails.root.join("db/seeds/buscar_paquetes_demo.rb")

  # ── Demo Pre-Factura + Venta (PR-D6.b) ──
  # Permite probar:
  #   - Vista de pre-factura con cargos auto (recolecta + cambio servicio).
  #   - Link "Imprimir Pre-Factura" desde el detalle del paquete.
  #   - Link "Ver Factura" desde el paquete cuando ya fue facturado.
  puts "Seeding pre-facturas + venta demo..."
  juan_demo = Cliente.find_by!(nombre: "Juan", apellido: "Perez")
  cer_envio = TipoEnvio.find_by!(codigo: "cer")
  amz_proveedor = Proveedor.find_by(nombre: "Amazon")

  # Helper local: prepara un paquete listo para entrar a pre-factura.
  crear_paquete_facturable = ->(tracking, **flags) {
    p = Paquete.find_or_initialize_by(tracking: tracking)
    p.assign_attributes(
      cliente: juan_demo,
      tipo_envio: cer_envio,
      sucursal: Sucursal.find_by(codigo: "MIA"),
      estado: "disponible_entrega",
      peso: 12.5, alto: 20, largo: 30, ancho: 25,
      cantidad_paquetes: 1, cantidad_productos: 1,
      descripcion: flags.delete(:descripcion) || "Demo PR-D6.b",
      proveedor: amz_proveedor,
      expedido_por: "UPS",
      fecha_recibido_miami: 7.days.ago
    )
    flags.each { |k, v| p[k] = v }
    p.recolecta_moneda ||= "USD" if flags[:recolecta_solicitada]
    p.save!
    p
  }

  pkg_pf1 = crear_paquete_facturable.call(
    "1Z999PFDEMO00001",
    descripcion: "Demo paquete con recolecta",
    recolecta_solicitada: true, recolecta_monto: 35.00
  )
  pkg_pf2 = crear_paquete_facturable.call(
    "1Z999PFDEMO00002",
    descripcion: "Demo paquete con cambio de servicio",
    solicito_cambio_servicio: true
  )
  pkg_pf3 = crear_paquete_facturable.call(
    "1Z999PFDEMO00003",
    descripcion: "Demo paquete con AMBOS cargos auto",
    recolecta_solicitada: true, recolecta_monto: 50.00,
    solicito_cambio_servicio: true
  )
  pkg_facturado = crear_paquete_facturable.call(
    "1Z999PFDEMO00004",
    descripcion: "Demo paquete que ya está facturado",
    recolecta_solicitada: true, recolecta_monto: 30.00
  )

  # Pre-factura 1: estado "creado" — todavía sin facturar.
  pf_creado = PreFactura.where(cliente: juan_demo).where("numero LIKE 'PF-%'")
                        .order(:id).first
  if pf_creado.nil? || pf_creado.pre_factura_items.where(paquete: [ pkg_pf1, pkg_pf2, pkg_pf3 ]).empty?
    pf_creado = PreFactura.build_from_paquetes(juan_demo, [ pkg_pf1.id, pkg_pf2.id, pkg_pf3.id ])
    pf_creado.save!
    [ pkg_pf1, pkg_pf2, pkg_pf3 ].each { |p| p.update_column(:pre_factura_id, pf_creado.id) }
  end

  # Pre-factura 2: facturada → genera Venta + link "Ver Factura".
  pf_facturada = PreFactura.joins(:pre_factura_items)
                           .where(pre_factura_items: { paquete_id: pkg_facturado.id })
                           .first
  if pf_facturada.nil?
    pf_facturada = PreFactura.build_from_paquetes(juan_demo, [ pkg_facturado.id ])
    pf_facturada.save!
    pkg_facturado.update_column(:pre_factura_id, pf_facturada.id)
    pf_facturada.confirmar!
    pf_facturada.facturar!
  end

  puts "  ✓ #{PreFactura.count} pre-facturas (1 creado, 1 facturada)"
  puts "  ✓ #{Venta.count} ventas demo"
  puts "    → Probar PF en: /pre_facturas/#{pf_creado.id}"
  puts "    → Probar Venta en: /ventas/#{pf_facturada.venta_id || Venta.last&.id}"
  puts "    → Detalle paquete con link a PF: /paquetes/#{pkg_pf3.id}"
  puts "    → Detalle paquete con link a Venta: /paquetes/#{pkg_facturado.id}"
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
