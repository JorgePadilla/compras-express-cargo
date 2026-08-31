# `RP-58` · Cómo se llama cada sección y en qué bloque vive.
#
# `PermisosDelSistema.politica` sabe **quién** entra a cada llave, pero no cómo
# se llama ni dónde está en el menú. Eso hace falta para dibujar la pantalla de
# permisos, y no puede salir del sidebar: ahí los nombres están mezclados con el
# markup y hay llaves que no tienen link —`:operacion` son las herramientas
# compartidas de los dos mostradores, no una pantalla—.
#
# Los grupos son los del menú a propósito: la pantalla de permisos tiene que
# leerse igual que lo que Yusef ve todos los días, no como una lista alfabética
# de símbolos.
#
# **Un lint compara esta lista contra las llaves del `case`, en las dos
# direcciones.** Una llave que esté acá y no en el código deja una fila muerta;
# una que esté en el código y no acá desaparece de la pantalla — y nadie se
# entera hasta que alguien pregunta por qué no puede prender algo.
module SeccionesDelSistema
  TODAS = {
    # ── Miami: el mostrador ──
    etiquetar:            { nombre: "Etiquetar",                 grupo: "Miami" },
    entrega_personal:     { nombre: "Entrega Personal",          grupo: "Miami" },

    # ── Logística: mover la carga ──
    manifiestos:          { nombre: "Manifiestos",               grupo: "Logística" },
    guias_aduana:         { nombre: "Guías y aduana",            grupo: "Logística" },
    recibir_carga:        { nombre: "Recibir Carga",             grupo: "Logística" },
    pre_alertas:          { nombre: "Pre-Alertas",               grupo: "Logística" },
    paquetes:             { nombre: "Todos los Paquetes",        grupo: "Logística" },

    # ── Transversal ──
    clientes:             { nombre: "Clientes",                  grupo: "Transversal" },
    tareas:               { nombre: "Tareas",                    grupo: "Transversal" },
    operacion:            { nombre: "Herramientas de mostrador", grupo: "Transversal",
                            ayuda: "Buscar un cliente, cotizar un flete, tocar el tracking de un paquete. No es una pantalla del menú." },

    # ── Facturación y cobro ──
    pre_facturas:         { nombre: "Pre-Facturas",              grupo: "Facturación y cobro" },
    cotizaciones:         { nombre: "Cotizaciones",              grupo: "Facturación y cobro" },
    ventas:               { nombre: "Facturas",                  grupo: "Facturación y cobro" },
    recibos:              { nombre: "Recibos",                   grupo: "Facturación y cobro" },
    notas_debito:         { nombre: "Notas de Débito",           grupo: "Facturación y cobro" },
    notas_credito:        { nombre: "Notas de Crédito",          grupo: "Facturación y cobro" },
    financiamientos:      { nombre: "Financiamientos",           grupo: "Facturación y cobro" },
    caja:                 { nombre: "Caja Diaria",               grupo: "Facturación y cobro" },

    # ── Operación ──
    entregas:             { nombre: "Entregas",                  grupo: "Operación" },
    marketing:            { nombre: "Marketing",                 grupo: "Operación" },

    # ── Configuración: hoy solo admin ──
    catalogos_manifiesto: { nombre: "Catálogos del Manifiesto",  grupo: "Configuración" },
    sucursales:           { nombre: "Sucursales",                grupo: "Configuración" },
    servicios:            { nombre: "Tabla de Servicios",        grupo: "Configuración" },
    servicios_extra:      { nombre: "Servicios Extra",           grupo: "Configuración" },
    tarifas_recolecta:    { nombre: "Tarifas de Recolecta",      grupo: "Configuración" },
    categoria_precios:    { nombre: "Categorías de Precio",      grupo: "Configuración" },
    proveedores:          { nombre: "Proveedores",               grupo: "Configuración" },
    motivos_retencion:    { nombre: "Motivos de Retención",      grupo: "Configuración" },
    motivos_envio_politica: { nombre: "Motivos de Envío por Política", grupo: "Configuración" },
    plantillas_notas_cliente: { nombre: "Plantillas Notas Cliente", grupo: "Configuración" },
    plantillas_descripcion: { nombre: "Plantillas Descripción",  grupo: "Configuración" },
    tasa_cambio:          { nombre: "Tasa de Cambio",            grupo: "Configuración" },
    ajustes_etiqueta:     { nombre: "Ajustes de Etiqueta",       grupo: "Configuración" },
    empresa_settings:     { nombre: "Datos de la Empresa",       grupo: "Configuración" },
    configuraciones:      { nombre: "Configuración general",     grupo: "Configuración" },
    reportes:             { nombre: "Reportes",                  grupo: "Configuración" },
    empleados:            { nombre: "Empleados",                 grupo: "Configuración" },
    usuarios:             { nombre: "Usuarios",                  grupo: "Configuración" },

    # ── La pantalla misma ──
    permisos:             { nombre: "Permisos por rol",          grupo: "Configuración" }
  }.freeze

  GRUPOS = TODAS.values.map { |s| s[:grupo] }.uniq.freeze

  module_function

  def por_grupo
    TODAS.group_by { |_llave, s| s[:grupo] }
  end

  def nombre(llave)
    TODAS.dig(llave.to_sym, :nombre) || llave.to_s.humanize
  end
end
