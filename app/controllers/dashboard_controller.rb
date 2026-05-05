class DashboardController < ApplicationController
  DASHBOARD_ROLES = %w[admin supervisor_miami supervisor_caja supervisor_prefactura].freeze

  before_action :redirect_cliente_to_portal
  before_action :require_dashboard_access

  def index
    metrics = DashboardMetrics.new.to_h
    metrics.each { |key, value| instance_variable_set("@#{key}", value) }
    @shortcut_groups = build_shortcut_groups
  end

  private

  # Construye los grupos de shortcuts del dashboard respetando el matrix de
  # `can_access?` (Authorization concern). Cada grupo tiene `area` y `cards`,
  # y solo se incluye si tiene al menos una card visible para el rol actual.
  def build_shortcut_groups
    groups = []

    log = []
    log << card("Etiquetar",          "Recibir paquetes",           "tag",                    etiquetar_path,    :navy) if can_access?(:etiquetar)
    log << card("Manifiestos",        "Empaque y envío",            "cube",                   manifiestos_path,  :navy) if can_access?(:manifiestos)
    log << card("Pre-Alertas",        "Recepciones esperadas",      "bell-alert",             pre_alertas_path,  :navy) if can_access?(:pre_alertas)
    log << card("Todos los Paquetes", "Búsqueda y reportes",        "archive-box",            paquetes_path,     :navy) if can_access?(:paquetes)
    groups << { area: "Logística", cards: log } if log.any?

    fac = []
    fac << card("Pre-Facturas",      nil, "document-text",            pre_facturas_path,    :teal) if can_access?(:pre_facturas)
    fac << card("Cotizaciones",      nil, "clipboard-document-list",  cotizaciones_path,    :teal) if can_access?(:cotizaciones)
    fac << card("Facturas",          nil, "currency-dollar",          ventas_path,          :teal) if can_access?(:ventas)
    fac << card("Recibos",           nil, "receipt-percent",          recibos_path,         :teal) if can_access?(:recibos)
    fac << card("Notas de Débito",   nil, "document-plus",            notas_debito_path,    :teal) if can_access?(:notas_debito)
    fac << card("Notas de Crédito",  nil, "document-minus",           notas_credito_path,   :teal) if can_access?(:notas_credito)
    fac << card("Financiamientos",   nil, "banknotes",                financiamientos_path, :teal) if can_access?(:financiamientos)
    groups << { area: "Facturación y Cobro", cards: fac } if fac.any?

    ent = []
    ent << card("Entregas", "Despachos y rutas", "truck", entregas_path, :gold) if can_access?(:entregas)
    groups << { area: "Entregas", cards: ent } if ent.any?

    if can_access?(:caja)
      caja = [
        card("Mi Día",    nil, "calculator",            caja_path,          :gold),
        card("Ingresos",  nil, "arrow-trending-up",     ingresos_caja_path, :gold),
        card("Egresos",   nil, "arrow-trending-down",   egresos_caja_path,  :gold),
        card("Historial", nil, "clock",                 historial_caja_path, :gold)
      ]
      groups << { area: "Caja Diaria", cards: caja }
    end

    if can_access?(:clientes)
      groups << {
        area: "Clientes",
        cards: [
          card("Clientes",       "Lista y búsqueda", "users",     clientes_path,     :teal),
          card("Nuevo cliente",  nil,                "user-plus", new_cliente_path,  :teal)
        ]
      }
    end

    if can_access?(:marketing) || admin?
      groups << {
        area: "Marketing",
        cards: [
          card("Correos",  nil, "envelope",                  "#", :navy),
          card("WhatsApp", nil, "chat-bubble-left-right",    "#", :navy),
          card("SMS",      nil, "device-phone-mobile",       "#", :navy)
        ]
      }
    end

    if admin?
      groups << {
        area: "Configuración",
        cards: [
          card("Usuarios",             nil, "user-group",            users_path,            :red),
          card("Sucursales",           nil, "building-storefront",   sucursales_path,       :red),
          card("Categorías de Precio", nil, "tag",                   categoria_precios_path, :red),
          card("Empresa",              nil, "building-office-2",     empresa_path,          :red),
          card("Reportes",             nil, "table-cells",           "#",                   :red)
        ]
      }
    end

    groups
  end

  def card(title, subtitle, icon, href, accent)
    { title: title, subtitle: subtitle, icon: icon, href: href, accent: accent }
  end

  # Si hay una sesión de cliente activa, redirige al portal de cuenta antes
  # de procesar la vista de dashboard admin. Evita exponer la UI admin a un
  # cliente y mantiene la separación de contextos.
  def redirect_cliente_to_portal
    return unless cookies.signed[:cliente_session_id]
    return unless ClienteSession.exists?(id: cookies.signed[:cliente_session_id])

    redirect_to cuenta_root_path
  end

  # Requiere que el usuario autenticado tenga un rol con acceso al dashboard
  # admin (admin + supervisores). Otros roles son redirigidos a su sección
  # apropiada.
  def require_dashboard_access
    return if Current.user&.admin?
    return if DASHBOARD_ROLES.include?(Current.user&.rol)

    fallback = case Current.user&.rol
               when "cajero"           then caja_path
               when "digitador_miami"  then etiquetar_path
               when "entrega_despacho" then entregas_path
               when "sac"              then paquetes_path
               else new_session_path
               end

    redirect_to fallback, alert: "No tienes permiso para acceder al dashboard."
  end
end
