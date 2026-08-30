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
  { codigo: "MIA", codigo_ep: "SMI", nombre: "Miami",      pais: "USA",      ubicacion: "miami",    codigo_recepcion_prefix: "RMI", recibe_carga: true, recepcion_por_defecto: true },
  { codigo: "SPS", codigo_ep: "SZR", nombre: "Zeron SPS",  pais: "Honduras", ubicacion: "honduras", codigo_recepcion_prefix: "RZE" },
  { codigo: "TGU", codigo_ep: "SHU", nombre: "Humuya TGU", pais: "Honduras", ubicacion: "honduras", codigo_recepcion_prefix: "RHU" },
  { codigo: "SAM", codigo_ep: "SSM", nombre: "San Manuel", pais: "Honduras", ubicacion: "honduras", codigo_recepcion_prefix: "RSM" },
  # C18-02, seguimiento del 2026-08-27. Yusef: *"Sería bueno tener otro como de
  # prueba, tipo México"*. Recibe carga y no es la de por defecto: el chooser
  # de /etiquetar pregunta, con Miami preseleccionada. Sin prefijo: el número
  # sale del código (RDFM2608000001). Se desactiva desde /sucursales cuando
  # estorbe.
  { codigo: "DFM", codigo_ep: "SDF", nombre: "DF México",  pais: "México",   ubicacion: "otros",    recibe_carga: true }
].each do |attrs|
  Sucursal.find_or_create_by!(codigo: attrs[:codigo]) do |s|
    s.assign_attributes(attrs)
  end
  # Backfill defensivo para sucursales que ya existían sin codigo_ep.
  s = Sucursal.find_by(codigo: attrs[:codigo])
  s.update_column(:codigo_ep, attrs[:codigo_ep]) if s && s.codigo_ep.blank?
end
# La sucursal de retiro «de siempre» (PR-C7.32). La migración la backfilleó con
# los datos, pero una base que se reseedea después nacía sin ninguna, y ahí el
# aviso de bolsa vuelve a salir para San Pedro — Jorge lo vio en staging el
# 2026-08-25: *"el modal guardar en San Pedro Sula no debería salir al final…
# y acaba de aparecer"*. Solo si no hay ninguna: la que elijan desde
# `/sucursales` manda.
unless Sucursal.exists?(retiro_por_defecto: true)
  Sucursal.find_by(codigo: "SPS")&.update_column(:retiro_por_defecto, true)
end
# Y lo mismo para recibir (C18-02): una base re-sembrada nacía sin ninguna
# sucursal que recibiera carga —el backfill vivía solo en la migración— y
# /etiquetar no ofrecía nada. Sin «recepción por defecto», el orden por nombre
# decidía. Miami si recibe; si no, la primera que reciba.
unless Sucursal.de_recepcion.exists?
  Sucursal.find_by(codigo: "MIA")&.update_column(:recibe_carga, true)
end
unless Sucursal.exists?(recepcion_por_defecto: true)
  (Sucursal.de_recepcion.find_by(ubicacion: "miami") || Sucursal.de_recepcion.first)&.update_column(:recepcion_por_defecto, true)
end
puts "  ✓ #{Sucursal.count} sucursales (retiro por defecto: #{Sucursal.find_by(retiro_por_defecto: true)&.nombre || 'ninguna'}; " \
     "recepción por defecto: #{Sucursal.find_by(recepcion_por_defecto: true)&.nombre || 'ninguna'})"

# ── Tipos de envio (v4.0 — ver docs/approved/pre_alerta_v4.docx) ──
[
  { nombre: "EXPRESS", codigo: "express", con_reempaque: true,  consolidable: true,
    precio_libra: 7.50, modalidad: "aereo",    sla: "3-7 dias habiles",   max_paquetes_por_accion: nil },
  { nombre: "CER",     codigo: "cer",     con_reempaque: true,  consolidable: true,
    precio_libra: 4.50, modalidad: "aereo",    sla: "6-10 dias habiles",  max_paquetes_por_accion: nil },
  { nombre: "CEM",     codigo: "cem",     con_reempaque: true,  consolidable: true,
    precio_libra: 2.50, modalidad: "maritimo", sla: "14-17 dias habiles", max_paquetes_por_accion: nil },
  { nombre: "CKA",     codigo: "cka",     con_reempaque: false, consolidable: false,
    precio_libra: 4.00, modalidad: "aereo",    sla: "6-10 dias habiles",  max_paquetes_por_accion: 1 },
  { nombre: "CKM",     codigo: "ckm",     con_reempaque: false, consolidable: false,
    precio_libra: 1.90, modalidad: "maritimo", sla: "14-17 dias habiles", max_paquetes_por_accion: 1 }
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

# ── Catálogos del manifiesto (C21-08) ──
#
# El deploy de staging **solo migra, no siembra**, así que sin esto los cuatro
# catálogos que estrenó `PR-M1` nacen vacíos y lo primero que ve Yusef del
# portal son pestañas en blanco.
#
# Es **semilla de arranque, no verdad**: los nombres salen de la pantalla vieja
# y de lo que él nombró en la reunión, y el equipo los ajusta por el CRUD —
# *"entre más cosas nos dejes crear, menos te molestaremos"*.

# Los diez tamaños de la pantalla vieja, en su orden. Las medidas van en nil a
# propósito salvo la que se pudo derivar: la pantalla vieja muestra 595.78 de
# volumen para 46×43×50, que es exactamente lo que da `VolumetricoCalculator`
# con su divisor de 166. Las otras nueve las carga Miami con la cinta métrica,
# y de todos modos se editan caja por caja (*"EH cortada"*).
[
  { nombre: "Especificar",  position: 1 },   # sin medidas a propósito
  { nombre: "EH",           position: 2 },
  { nombre: "D",            position: 3 },
  { nombre: "22 Cubo",      position: 4 },
  { nombre: "18 Cubo",      position: 5 },
  { nombre: "D G",          position: 6 },
  { nombre: "EH G",         position: 7 },
  { nombre: "E",            position: 8 },
  { nombre: "Mini D",       position: 9, alto: 46, largo: 43, ancho: 50 },
  { nombre: "Mini D Doble", position: 10 }
].each do |attrs|
  TamanoCaja.find_or_create_by!(nombre: attrs[:nombre]) do |t|
    t.position = attrs[:position]
    t.alto  = attrs[:alto]
    t.largo = attrs[:largo]
    t.ancho = attrs[:ancho]
    t.activo = true
  end
end
puts "  ✓ #{TamanoCaja.count} tamaños de caja"

# El tipo de envío DEL PROVEEDOR — no confundir con `TipoEnvio`, que es el
# nuestro. Los dos que nombró Yusef mirando el impreso.
[ "AEREO EXPRESS", "CKM MARITIMO" ].each.with_index(1) do |nombre, i|
  TipoEnvioProveedor.find_or_create_by!(nombre: nombre) do |t|
    t.position = i
    t.activo = true
  end
end
puts "  ✓ #{TipoEnvioProveedor.count} tipos de envío del proveedor"

# El consignatario que nombró: *"qué consignatario somos nosotros"*.
Consignatario.find_or_create_by!(nombre: "CORPORACION KARSAM") { |c| c.activo = true }
puts "  ✓ #{Consignatario.count} consignatarios"

# ── Categorias de precio ──
# Solo el nombre: una categoria agrupa clientes, no guarda precios. Los precios
# de cada categoria los siembra `TarifasPropuesta2026` sobre `tarifas`, con su
# moneda explicita.
#
# "Regular" y "VIP" son las de la epoca vieja y la hoja de Yusef no las declara;
# se dejan de sembrar. Los clientes que las tengan asignadas se mueven con
# `rake tarifas:migrar_categorias_viejas`.
[ "Mayorista" ].each do |nombre|
  CategoriaPrecio.find_or_create_by!(nombre: nombre)
end
puts "  ✓ #{CategoriaPrecio.count} categorias de precio"

# ── Tarifas reales (PR-10.g) ──
# Crea el resto de las categorías (Clientes Amigos, doTERRA, Shein, Personal
# CEC, Sin Cobro Mínimo…) y las tarifas de la hoja PROPUESTA de Yusef.
# Vive en `lib/tarifas_propuesta_2026.rb` para poder re-aplicarse sola cuando
# manden una corrección de precios: `bin/rails tarifas:sembrar_propuesta_2026`.
TarifasPropuesta2026.sembrar!(verbose: true)

# ── Configuraciones ──
{
  # PR-C6.29: 27.10 es la tasa con la que Yusef hace sus cuentas — la escribió
  # sobre el PDF de preguntas al confirmar el mínimo de CER (4.50 × 1.5 =
  # 182.93 + ISV = 210.36). Con la 24.85 que había, ese mismo paquete caía en
  # el mínimo y daba L.200: sus números no reproducían.
  "tasa_cambio" => { valor: "27.10", tipo: "decimal", categoria: "moneda" },
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

# ── Plantillas de Descripción (C19-04, PR-C7.58) ──
# Yusef, 2026-08-28: "hay dos cosas: sellado y compra chino, son más comunes".
puts "Seeding plantillas_descripcion..."
[
  { titulo: "Sellado",     texto: "Sellado",     position: 0 },
  { titulo: "Compra chino", texto: "Compra chino", position: 1 }
].each do |attrs|
  PlantillaDescripcion.find_or_create_by!(titulo: attrs[:titulo]) do |p|
    p.texto    = attrs[:texto]
    p.position = attrs[:position]
  end
end
puts "  ✓ #{PlantillaDescripcion.count} plantillas de descripción"

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

# ── Motivos de envío por política (C18-06) ──
# Solo los dos que Yusef leyó textuales del sistema viejo, donde los tienen
# guardados y los copian y pegan (Conversación 18, 2026-08-26): *"Enviado según
# política de envío por falta de identificación o pre-alerta"* y *"sellados y
# enviados según políticas de envío por falta de identificación"*. Lo demás que
# mencionó —«etiqueta incompleta», «solo se lee Juan», «desconocido»— es el
# contenido de cada caso, no una frase estándar: eso lo escriben en el detalle,
# o lo agregan al catálogo desde /motivos_envio_politica. Jorge, 2026-08-27:
# *"pongamos unas seeds ahí con dos ejemplos"*; y Yusef, desde abril: *"entre
# más cosas nos dejes crear, menos te molestaremos"*.
puts "Seeding motivos_envio_politica..."
[
  { nombre: "Sin pre-alerta ni identificación", texto_al_cliente: "Enviado según política de envío por falta de identificación o pre-alerta.", position: 0 },
  { nombre: "Sellado y enviado",                texto_al_cliente: "Sellado y enviado según políticas de envío por falta de identificación.", position: 1 }
].each do |attrs|
  MotivoEnvioPolitica.find_or_create_by!(nombre: attrs[:nombre]) do |m|
    m.texto_al_cliente = attrs[:texto_al_cliente]
    m.position         = attrs[:position]
  end
end
puts "  ✓ #{MotivoEnvioPolitica.count} motivos de envío por política"

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
  # Yusef 2026-08-08, en el audio de precios: "es un ajuste que se le hace por
  # hacer cambio de servicio que son los **100 lempiras**. Yo te lo puse que
  # eran 5". Estaba cargado en $15 USD, que son ~L.373 — 3.7× de más, y este
  # cargo **se auto-genera** en nota de débito al facturar.
  #
  # Va con el ISV adentro a propósito, distinto de los cinco de la hoja
  # (`ServiciosExtraPropuesta2026`, que van netos porque la hoja dice "PRECIOS
  # NO INCLUYEN IMPUESTOS"). Este número no vino de la hoja sino del audio, y
  # ahí Yusef habla del precio final: los 100 son lo que paga el cliente. Con
  # el flag en true el CRUD le muestra **100**, que es su número, y
  # `precio_venta_sin_isv` guarda los 86.96 que van a la línea.
  { codigo: "CAMBIO_SERVICIO", descripcion: "Cambio de servicio (aéreo↔marítimo, con/sin reempaque)",
    costo: 0, precio_venta: 100.00, moneda: "LPS", precio_incluye_isv: true, position: 0 },
  { codigo: "PESO_ADICIONAL",  descripcion: "Peso adicional declarado vs medido",
    costo: 0, precio_venta: 0,     moneda: "USD", precio_incluye_isv: true, position: 1 },
  { codigo: "MANEJO_ESPECIAL", descripcion: "Manejo especial (frágil, voluminoso, perecedero)",
    costo: 0, precio_venta: 10.00, moneda: "USD", precio_incluye_isv: true, position: 2 }
].each do |attrs|
  ServicioExtra.find_or_create_by!(codigo: attrs[:codigo]) do |s|
    s.assign_attributes(attrs.merge(activo: true))
  end
end

# ── Cargos de la hoja de Yusef (PR-10.i) ──
# Solo los cinco que su propio texto define sin ambigüedad. Los otros diez
# necesitan que confirme la moneda — la tarea imprime cuáles y por qué:
#   bin/rails tarifas:sembrar_cargos_2026
ServiciosExtraPropuesta2026.sembrar!(verbose: true)

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
    # PR-13.c: los tres supervisores que autorizan cambios de precio arrancan
    # con PIN para poder probar el flujo. `pin_cambiado_at` queda en nil a
    # propósito: es exactamente el estado "el admin te lo asignó, cambialo".
    { nombre: "Supervisor Pre-Factura", email: "sup_prefactura@cec.com",
      rol: "supervisor_prefactura", ubicacion: "honduras", pin: "1111" },
    { nombre: "Supervisor SAC", email: "sup_sac@cec.com",
      rol: "supervisor_sac", ubicacion: "honduras", pin: "2222" },
    { nombre: "Entrega", email: "entrega@cec.com", rol: "entrega_despacho", ubicacion: "honduras" }
  ].each do |attrs|
    user = User.find_or_initialize_by(email_address: attrs[:email])
    user.nombre = attrs[:nombre]
    user.rol = attrs[:rol]
    user.ubicacion = attrs[:ubicacion]
    user.password = "Demo123!"
    user.pin = attrs[:pin] if attrs[:pin]
    user.save!
  end
  # Al Supervisor Caja que ya existía también, para tener los cuatro roles.
  User.find_by(email_address: "sup_caja@cec.com")&.update!(pin: "3333")
  puts "  ✓ #{User.count} users total (including demo)"

  # Demo clients
  #
  # "Regular" y "VIP" eran las categorias de la epoca vieja y ya no existen: la
  # hoja de precios de Yusef no las declara y `BorrarCategoriasViejasSinUso` las
  # saco. Los clientes demo usan el mismo criterio que se le aplico a los reales
  # en PR-C7.08, para que dev se comporte como produccion:
  #
  #   los que eran regular -> sin categoria (pagan precio de lista)
  #   los que eran vip     -> Clientes Amigos
  #
  # `find_by` sin bang a proposito: si por lo que sea la categoria no esta
  # sembrada todavia, los clientes demo se crean igual y sin categoria, en vez de
  # tumbar el seed entero.
  regular = nil
  vip = CategoriaPrecio.find_by(nombre: "Clientes Amigos")
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

  # Demo paquetes con transiciones progresivas (Yusef 2026-05-12):
  # Cada paquete arranca en `recibido_miami` y avanza estado a estado para
  # que el callback `track_estado_fecha_y_user` setee fecha+user en cada
  # paso. Después backdatean los fechas con update_columns para que la
  # línea de tiempo se vea realista en demos.
  digitador = User.find_by!(email_address: "digitador@cec.com")
  Current.session = Session.new(user: digitador)
  aereo = TipoEnvio.find_by!(codigo: "cer")
  maritimo = TipoEnvio.find_by!(codigo: "cem")
  tarifa_demo = (TarifaRecolecta.respond_to?(:activos) ? TarifaRecolecta.activos.first : nil) || TarifaRecolecta.first
  clientes = Cliente.all.to_a
  carriers = %w[FedEx DHL UPS USPS Amazon]
  proveedores = Proveedor.all.to_a

  # Orden del pipeline. La progresión se detiene al `final` de cada profile.
  estado_pipeline = %w[recibido_miami empacado enviado_honduras en_aduana
                       consolidando_honduras disponible_entrega en_reparto entregado]

  # 20 perfiles distribuidos en el pipeline para que el demo refleje el
  # ciclo completo (incluyendo paquetes detenidos en cada hito).
  profiles = [
    { final: "recibido_miami",        dias_recibido: 1 },
    { final: "recibido_miami",        dias_recibido: 3 },
    { final: "empacado",              dias_recibido: 5 },
    { final: "empacado",              dias_recibido: 6 },
    { final: "empacado",              dias_recibido: 8 },
    { final: "enviado_honduras",      dias_recibido: 10 },
    { final: "enviado_honduras",      dias_recibido: 12 },
    { final: "en_aduana",             dias_recibido: 14 },
    { final: "en_aduana",             dias_recibido: 15 },
    { final: "consolidando_honduras", dias_recibido: 18, recolecta: true },
    { final: "consolidando_honduras", dias_recibido: 20 },
    { final: "disponible_entrega",    dias_recibido: 22 },
    { final: "disponible_entrega",    dias_recibido: 24, recolecta: true },
    { final: "disponible_entrega",    dias_recibido: 25 },
    { final: "en_reparto",            dias_recibido: 27 },
    { final: "en_reparto",            dias_recibido: 28, recolecta: true },
    { final: "entregado",             dias_recibido: 30 },
    { final: "entregado",             dias_recibido: 35 },
    { final: "entregado",             dias_recibido: 40, recolecta: true },
    { final: "entregado",             dias_recibido: 45 }
  ]

  profiles.each_with_index do |profile, i|
    tracking = "1Z999TEST#{(i + 1).to_s.rjust(6, '0')}"
    next if Paquete.exists?(tracking: tracking)

    recibido_at = profile[:dias_recibido].days.ago

    paquete = Paquete.create!(
      tracking: tracking,
      cliente: clientes[i % clientes.length],
      tipo_envio: i.even? ? aereo : maritimo,
      estado: "recibido_miami",
      peso: rand(1.0..50.0).round(2),
      alto: rand(5.0..30.0).round(2),
      largo: rand(5.0..40.0).round(2),
      ancho: rand(5.0..30.0).round(2),
      cantidad_productos: rand(1..5),
      cantidad_paquetes: 1,
      descripcion: ["Ropa variada", "Zapatos Nike", "Electronica", "Suplementos", "Libros", "Juguetes", "Cosmeticos", "Accesorios"][i % 8],
      proveedor: proveedores[i % proveedores.length],
      expedido_por: carriers[i % carriers.length],
      pre_alerta: i % 5 == 0,
      solicito_cambio_servicio: i == 3,
      retener_miami: i == 7 && profile[:final] == "recibido_miami",
      user: digitador
    )
    paquete.update_columns(fecha_recibido_miami: recibido_at)

    if profile[:recolecta] && tarifa_demo
      paquete.update_columns(
        recolecta_solicitada: true,
        tarifa_recolecta_id: tarifa_demo.id,
        recolecta_monto: tarifa_demo.monto,
        recolecta_moneda: tarifa_demo.moneda,
        fecha_solicito_recolecta: recibido_at + 12.hours,
        fecha_solicito_recolecta_by_user_id: digitador.id
      )
    end

    next if profile[:final] == "recibido_miami"

    # Avanzar por cada estado intermedio hasta `final`. Cada update!
    # dispara el callback (fecha+user via Time.current); luego backdatea.
    final_idx = estado_pipeline.index(profile[:final])
    estados_a_transitar = estado_pipeline[1..final_idx]
    estados_a_transitar.each_with_index do |estado, paso|
      paquete.update!(estado: estado)
      fecha_attr = Paquete::ESTADO_FECHA_MAP[estado]
      next unless fecha_attr
      paquete.update_columns(fecha_attr => recibido_at + (paso + 1).days)
    end
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
  # Si tiene recolecta_solicitada, también setea fecha + tarifa para que
  # el step "Solicitud Recolecta" aparezca en la línea de tiempo.
  Current.session = Session.new(user: digitador)
  tarifa_pf_demo = (TarifaRecolecta.respond_to?(:activos) ? TarifaRecolecta.activos.first : nil) || TarifaRecolecta.first
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
    if flags[:recolecta_solicitada] && tarifa_pf_demo
      p.update_columns(
        tarifa_recolecta_id: tarifa_pf_demo.id,
        fecha_solicito_recolecta: 7.days.ago + 4.hours,
        fecha_solicito_recolecta_by_user_id: digitador.id
      )
    end
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
  puts "    → Probar Venta en: /ventas/#{Venta.last&.id}"
  puts "    → Detalle paquete con link a PF: /paquetes/#{pkg_pf3.id}"
  puts "    → Detalle paquete con link a Venta: /paquetes/#{pkg_facturado.id}"

  # ── 4 paquetes "demo completo" — todos los campos llenos (PR-D7.n) ──
  # Para revisar todas las features juntas: notas (5 tipos), tareas (3
  # estados), recolecta, retención, manifest, pre-factura, fechas
  # editables, etc.
  puts "Seeding 4 paquetes demo completos..."
  Current.session = Session.new(user: digitador)
  juan      = Cliente.find_by!(nombre: "Juan",  apellido: "Perez")
  maria     = Cliente.find_by!(nombre: "Maria", apellido: "Lopez")
  sofia     = Cliente.find_by(nombre: "Sofia", apellido: "Garcia") || juan
  ana       = Cliente.find_by(nombre: "Ana",    apellido: "Martinez") || maria
  cer       = TipoEnvio.find_by!(codigo: "cer")
  cem       = TipoEnvio.find_by!(codigo: "cem")
  exp_envio = TipoEnvio.find_by(codigo: "exp") || cer
  amz       = Proveedor.find_by(nombre: "Amazon")
  wmt       = Proveedor.find_by(nombre: "Walmart") || amz
  tgt       = Proveedor.find_by(nombre: "Target") || amz
  ebay      = Proveedor.find_by(nombre: "eBay") || amz
  tarifa_sps  = TarifaRecolecta.find_by(zona: "SPS Centro") || TarifaRecolecta.first
  sucursal_sps = Sucursal.find_by(codigo_ep: "SZR") || Sucursal.first

  motivo_dano = MotivoRetencion.find_or_create_by!(nombre: "Caja dañada") { |m| m.activo = true }
  motivo_pago = MotivoRetencion.find_or_create_by!(nombre: "Pago pendiente") { |m| m.activo = true }

  juan.update!(
    notas_miami:    juan.notas_miami.presence    || "Cliente VIP. Re-empacar todo en cajas nuevas con stickers.",
    notas_honduras: juan.notas_honduras.presence || "Entrega solo entre 9am-12pm. Tel: 9999-0000.",
    notas_caja:     juan.notas_caja.presence     || "Acepta L. en cualquier denominación.",
    notas_sac:      juan.notas_sac.presence      || "Prefiere comunicación vía WhatsApp."
  )

  # ── Paquete 1: ENTREGADO — pipeline completo + recolecta + tareas ──
  pkg1 = Paquete.find_or_initialize_by(tracking: "1Z999FULL-DEMO-001")
  if pkg1.new_record?
    pkg1.assign_attributes(
      cliente: juan, tercero: maria,
      tipo_envio: cer, proveedor: amz, expedido_por: "UPS",
      tracking_secundario: "9400111899560FULL0001",
      remitente: "Walmart Logistics LLC",
      sucursal: Sucursal.find_by(codigo: "MIA"),
      sucursal_actual: sucursal_sps,
      estado: "recibido_miami",
      peso: 18.5, alto: 25, largo: 35, ancho: 30,
      cantidad_paquetes: 2, cantidad_productos: 5,
      descripcion: "Ropa deportiva: 3 conjuntos Nike + 2 pares de tenis Adidas. Total 5 productos divididos en 2 cajas (12x12x10 + 18x18x14).",
      notas_internas: "Cliente VIP, priorizar empaque rápido. Etiquetar como FRÁGIL las dos cajas. Coordinar con repartidor.",
      notas_al_cliente: "Su pedido fue empacado con cuidado adicional. Cualquier consulta puede contactarnos vía WhatsApp al 9999-0000.",
      notas_consolidacion: "Paquete pertenece a pre-alerta consolidada de marzo. Esperar consolidación completa antes de despachar.",
      notas_retencion: "",
      pre_alerta: true,
      recolecta_solicitada: true,
      tarifa_recolecta: tarifa_sps,
      recolecta_monto: tarifa_sps.monto, recolecta_moneda: tarifa_sps.moneda,
      user: digitador
    )
    pkg1.save!
    pkg1.update_columns(
      fecha_solicito_recolecta: 25.days.ago,
      fecha_solicito_recolecta_by_user_id: digitador.id,
      fecha_recibido_miami: 20.days.ago,
      fecha_recibido_miami_by_user_id: digitador.id
    )
    # Avanzar por todo el pipeline
    %w[empacado enviado_honduras en_aduana consolidando_honduras disponible_entrega en_reparto entregado].each_with_index do |estado, i|
      pkg1.update!(estado: estado)
      attr = Paquete::ESTADO_FECHA_MAP[estado]
      pkg1.update_columns(attr => 20.days.ago + (i + 2).days) if attr
    end
    pkg1.update_columns(fecha_posible_entrega: 12.days.ago)
  end

  # Pre-alerta + tareas para pkg1
  pa1_full = PreAlerta.find_or_create_by!(numero_documento: "PA-FULL-001") do |pa|
    pa.cliente = juan
    pa.tipo_envio = cer
    pa.titulo = "Compra Nike + Adidas marzo"
    pa.con_reempaque = true
    pa.consolidado = true
    pa.creado_por_tipo = "cliente"
    pa.creado_por_id = juan.id
  end
  PreAlertaPaquete.find_or_create_by!(pre_alerta: pa1_full, tracking: pkg1.tracking) do |pap|
    pap.paquete = pkg1
    pap.descripcion = pkg1.descripcion
    pap.instrucciones = "Si el calzado viene en caja original, NO la abran. Si la talla del pantalón es L, contactarme antes de empacar."
    pap.fecha = 28.days.ago.to_date
  end
  if pkg1.tareas.none?
    Tarea.create!(paquete: pkg1, titulo: "Confirmar tallas con cliente", descripcion: "Verificar talla L vs M en pantalones.", asignado_a: digitador, estado: "realizada", completado_por: digitador, completada_en: 18.days.ago, notas: "Cliente confirmó L para todo.")
    Tarea.create!(paquete: pkg1, titulo: "Llamar para coordinar entrega", asignado_a: digitador, estado: "realizada", completado_por: digitador, completada_en: 10.days.ago)
  end

  # ── Paquete 2: EN ADUANA — retenido + cambio servicio + sin recolecta ──
  pkg2 = Paquete.find_or_initialize_by(tracking: "1Z999FULL-DEMO-002")
  if pkg2.new_record?
    pkg2.assign_attributes(
      cliente: maria, tercero: nil,
      tipo_envio: cem, proveedor: wmt, expedido_por: "FedEx",
      tracking_secundario: nil,
      remitente: "Walmart e-commerce",
      sucursal: Sucursal.find_by(codigo: "MIA"),
      estado: "recibido_miami",
      peso: 45.0, alto: 50, largo: 60, ancho: 55,
      cantidad_paquetes: 1, cantidad_productos: 3,
      descripcion: "Electrodomésticos: licuadora, batidora, tostadora. Caja exterior con daño.",
      notas_internas: "Caja exterior abollada al recibir — fotografiado para reclamo a Walmart. Revisar contenido antes de enviar.",
      notas_al_cliente: "Estimado/a cliente, su paquete llegó con daño en la caja exterior. Estamos verificando el contenido antes de despachar. Le contactaremos si hay algún problema.",
      notas_consolidacion: "",
      retener_miami: true,
      notas_retencion: "Caja exterior abollada en transporte FedEx. Confirmar con cliente si desea proceder o reclamar. Fotos en carpeta /miami/danados/2026-05/",
      solicito_cambio_servicio: true,
      pre_alerta: true,
      recolecta_solicitada: false,
      user: digitador
    )
    pkg2.save!
    pkg2.motivos_retencion << motivo_dano unless pkg2.motivos_retencion.include?(motivo_dano)
    pkg2.update_columns(
      fecha_recibido_miami: 8.days.ago,
      fecha_recibido_miami_by_user_id: digitador.id
    )
    %w[empacado enviado_honduras en_aduana].each_with_index do |estado, i|
      pkg2.update!(estado: estado)
      attr = Paquete::ESTADO_FECHA_MAP[estado]
      pkg2.update_columns(attr => 8.days.ago + (i + 2).days) if attr
    end
    pkg2.update_columns(fecha_posible_entrega: 3.days.from_now)
  end

  # Pre-alerta + tareas para pkg2
  pa2_full = PreAlerta.find_or_create_by!(numero_documento: "PA-FULL-002") do |pa|
    pa.cliente = maria
    pa.tipo_envio = cem
    pa.titulo = "Electrodomésticos cocina"
    pa.con_reempaque = false
    pa.consolidado = false
    pa.creado_por_tipo = "usuario"
    pa.creado_por_id = digitador.id
  end
  PreAlertaPaquete.find_or_create_by!(pre_alerta: pa2_full, tracking: pkg2.tracking) do |pap|
    pap.paquete = pkg2
    pap.descripcion = pkg2.descripcion
    pap.instrucciones = "Por favor verificar que los 3 productos vengan completos. La licuadora es la prioridad."
    pap.fecha = 10.days.ago.to_date
  end
  if pkg2.tareas.none?
    Tarea.create!(paquete: pkg2, titulo: "Subir fotos del daño", descripcion: "Fotografiar la caja desde varios ángulos para reclamo.", asignado_a: digitador, estado: "realizada", completado_por: digitador, completada_en: 7.days.ago)
    Tarea.create!(paquete: pkg2, titulo: "Llamar al cliente para autorización", descripcion: "Cliente decide si proceder o reclamar.", asignado_a: digitador, estado: "en_proceso", notas: "Dejé mensaje en WhatsApp, esperando respuesta.")
    Tarea.create!(paquete: pkg2, titulo: "Coordinar cambio de servicio a CEM", asignado_a: digitador, estado: "pendiente")
  end

  # ── Paquete 3: RECIBIDO MIAMI — recién llegado con tareas pendientes ──
  pkg3 = Paquete.find_or_initialize_by(tracking: "1Z999FULL-DEMO-003")
  if pkg3.new_record?
    pkg3.assign_attributes(
      cliente: sofia, tercero: nil,
      tipo_envio: exp_envio, proveedor: tgt, expedido_por: "USPS",
      remitente: "Target Distribution",
      sucursal: Sucursal.find_by(codigo: "MIA"),
      estado: "recibido_miami",
      peso: 5.2, alto: 15, largo: 20, ancho: 18,
      cantidad_paquetes: 3, cantidad_productos: 12,
      descripcion: "Productos de bebé: 6 mamilas, 4 chupones, 2 sets de cobijas.",
      notas_internas: "Cliente nuevo. Confirmar dirección de entrega antes de despachar.",
      notas_al_cliente: "¡Bienvenido/a! Su primer envío con CEC. Le contactaremos cuando esté listo para retiro.",
      notas_consolidacion: "Cliente solicitó consolidación con próximo envío si llega antes del 25/05.",
      pre_alerta: true,
      user: digitador
    )
    pkg3.save!
    pkg3.update_columns(
      fecha_recibido_miami: 1.day.ago,
      fecha_recibido_miami_by_user_id: digitador.id
    )
  end

  pa3_full = PreAlerta.find_or_create_by!(numero_documento: "PA-FULL-003") do |pa|
    pa.cliente = sofia
    pa.tipo_envio = exp_envio
    pa.titulo = "Ajuar bebé Target"
    pa.con_reempaque = true
    pa.consolidado = true
    pa.creado_por_tipo = "cliente"
    pa.creado_por_id = sofia.id
  end
  PreAlertaPaquete.find_or_create_by!(pre_alerta: pa3_full, tracking: pkg3.tracking) do |pap|
    pap.paquete = pkg3
    pap.descripcion = pkg3.descripcion
    pap.instrucciones = "Las mamilas vienen en bolsas individuales — por favor NO las saquen del empaque original."
    pap.fecha = 2.days.ago.to_date
  end
  if pkg3.tareas.none?
    Tarea.create!(paquete: pkg3, titulo: "Confirmar dirección de entrega", descripcion: "Cliente nuevo — verificar dirección y horario.", asignado_a: digitador, estado: "pendiente")
    Tarea.create!(paquete: pkg3, titulo: "Verificar consolidación", descripcion: "Revisar si tiene otros envíos pendientes antes del 25/05.", estado: "pendiente")
  end

  # ── Paquete 4: ENTREGADO simple — flujo limpio sin retención ni recolecta ──
  pkg4 = Paquete.find_or_initialize_by(tracking: "1Z999FULL-DEMO-004")
  if pkg4.new_record?
    pkg4.assign_attributes(
      cliente: ana, tercero: nil,
      tipo_envio: cer, proveedor: ebay, expedido_por: "DHL",
      remitente: "eBay Seller — JoesCollectibles",
      sucursal: Sucursal.find_by(codigo: "MIA"),
      sucursal_actual: sucursal_sps,
      estado: "recibido_miami",
      peso: 2.8, alto: 10, largo: 15, ancho: 12,
      cantidad_paquetes: 1, cantidad_productos: 1,
      descripcion: "Reloj vintage Rolex (réplica) coleccionable.",
      notas_internas: "Producto coleccionable — manipular con extremo cuidado. Cliente quiere fotos antes de empacar.",
      notas_al_cliente: "Gracias por su compra. Adjuntamos foto del producto antes del empaque para su tranquilidad.",
      notas_consolidacion: "",
      user: digitador
    )
    pkg4.save!
    pkg4.update_columns(
      fecha_recibido_miami: 30.days.ago,
      fecha_recibido_miami_by_user_id: digitador.id
    )
    %w[empacado enviado_honduras en_aduana disponible_entrega en_reparto entregado].each_with_index do |estado, i|
      pkg4.update!(estado: estado)
      attr = Paquete::ESTADO_FECHA_MAP[estado]
      pkg4.update_columns(attr => 30.days.ago + (i + 2).days) if attr
    end
    pkg4.update_columns(fecha_posible_entrega: 24.days.ago)
  end

  if pkg4.tareas.none?
    Tarea.create!(paquete: pkg4, titulo: "Tomar foto pre-empaque", descripcion: "Cliente solicitó foto del producto antes de empacar.", asignado_a: digitador, estado: "realizada", completado_por: digitador, completada_en: 28.days.ago)
    Tarea.create!(paquete: pkg4, titulo: "Confirmar entrega con cliente", asignado_a: digitador, estado: "realizada", completado_por: digitador, completada_en: 25.days.ago)
    Tarea.create!(paquete: pkg4, titulo: "Encuesta de satisfacción", asignado_a: digitador, estado: "realizada", completado_por: digitador, completada_en: 23.days.ago, notas: "5/5 estrellas. Cliente muy contento.")
  end

  # Manifiestos demo — linkear pkg1, pkg2, pkg4 a manifiestos reales
  # para que el operador vea trazabilidad. pkg3 queda sin manifiesto
  # porque su estado es recibido_miami (aún no empacado).
  empresa_pronto = EmpresaManifiesto.find_by!(nombre: "PRONTO CARGO")

  mani_full_a = Manifiesto.find_or_create_by!(numero: "MA-FULL-001") do |m|
    m.empresa_manifiesto = empresa_pronto
    m.tipo_envio = "CER"
    m.estado = "enviado"
    m.fecha_enviado = 18.days.ago
    m.fecha_aduana = 17.days.ago
    m.user = digitador
  end

  mani_full_b = Manifiesto.find_or_create_by!(numero: "MA-FULL-002") do |m|
    m.empresa_manifiesto = empresa_pronto
    m.tipo_envio = "CER"
    m.estado = "enviado"
    m.fecha_enviado = 4.days.ago
    m.fecha_aduana = 3.days.ago
    m.user = digitador
  end

  # Idempotente: solo asignar si está sin manifiesto. update_column
  # bypasea el callback sync_dates_from_manifiesto (las fechas ya
  # están seteadas correctamente por el state walk; no queremos que
  # el callback las sobrescriba con los millis del manifiesto demo).
  { pkg1 => mani_full_a, pkg2 => mani_full_b, pkg4 => mani_full_a }.each do |paq, mani|
    paq.update_column(:manifiesto_id, mani.id) if paq.manifiesto_id.nil?
  end

  mani_full_a.recalculate_totals!
  mani_full_b.recalculate_totals!

  puts "  ✓ 4 paquetes demo completos creados:"
  puts "    → /paquetes/#{pkg1.id} — Entregado · pipeline completo + recolecta + 2 tareas · #{mani_full_a.numero}"
  puts "    → /paquetes/#{pkg2.id} — En aduana · retenido + cambio servicio + 3 tareas · #{mani_full_b.numero}"
  puts "    → /paquetes/#{pkg3.id} — Recibido Miami · cliente nuevo + 2 tareas pendientes · sin manifiesto"
  puts "    → /paquetes/#{pkg4.id} — Entregado simple · 3 tareas realizadas · #{mani_full_a.numero}"
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
