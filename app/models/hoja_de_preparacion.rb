# PR-P.4 · C30-15 · La hoja de preparación de la pre-factura.
#
# Yusef, 2026-10-09, dibujándola (foto 3): *"es como etiquetando… esa misma
# vista, no misma, pero así"* — primero el **tipo de servicio** (selección
# múltiple, *"porque en las cajas vienen dos tipos de servicios"*) **o**
# **editar pre-facturas**; después los **manifiestos**; después la **fecha de
# trabajo**.
#
# Vive en la **sesión** del usuario, como la sesión de `/etiquetar`: es cómo
# está parado el que trabaja, no un dato del sistema. Lo que tenga que durar
# (la hora del aviso) se copia a cada pre-factura cuando se guarda (`PR-P.5`).
#
# Este objeto no toca la base salvo para leer: arma y valida lo que va y viene
# de `session[:pf_hoja]`. La sesión de Rails se serializa en JSON, así que las
# claves van en string y la fecha en ISO 8601.
class HojaDePreparacion
  MODOS = %w[nuevas editar].freeze

  # C30-16 · *"El default es 7 y media… el sistema viene a las 7:30 y empieza a
  # mandar los mensajes."* La hora la administra el equipo en `Configuracion`
  # (`prefactura_hora_disponible`), y **la lee `PreFactura.hora_disponible`**
  # (PR-P.2). Esta hoja tenía su propio lector de la misma clave y los dos no
  # coincidían —QA: uno aceptaba «08:00:00» y el otro «8:00»—, así que la
  # hoja mostraba una hora y la pre-factura avisaba a otra. Ahora hay uno.
  #
  # `HORA` queda solo para lo que teclea el operario en el formulario, que no
  # es la clave: ahí se aceptan segundos y se tiran (`C30-08`).
  HORA = /\A([01]\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?\z/

  attr_reader :modo, :tipo_envio_ids, :manifiesto_ids, :disponible_en

  # La hora por defecto, siempre «HH:MM» para el campo y el rótulo.
  def self.hora_por_defecto
    disponible_por_defecto.strftime("%H:%M")
  end

  # Hoy a la hora por defecto. Hoy y no mañana: Yusef lo pone *"para ese mismo
  # día pero a una hora específica"*, y si la hora ya pasó el aviso sale al
  # apretar F9 (Fase 14, paso 3).
  def self.disponible_por_defecto
    PreFactura.notificar_at_para(Time.zone.today)
  end

  def self.desde_sesion(datos)
    datos = (datos || {}).to_h.stringify_keys
    new(modo: datos["modo"], tipo_envio_ids: datos["tipo_envio_ids"],
        manifiesto_ids: datos["manifiesto_ids"],
        disponible_en: (Time.zone.parse(datos["disponible_en"].to_s) if datos["disponible_en"].present?))
  end

  def initialize(modo: nil, tipo_envio_ids: [], manifiesto_ids: [], disponible_en: nil)
    @modo = MODOS.include?(modo.to_s) ? modo.to_s : "nuevas"
    @tipo_envio_ids = Array(tipo_envio_ids).compact_blank.map(&:to_i).uniq
    @manifiesto_ids = Array(manifiesto_ids).compact_blank.map(&:to_i).uniq
    @disponible_en = (disponible_en || self.class.disponible_por_defecto).change(sec: 0)
  end

  # Lo que mandó el formulario, encima de lo que ya había. La fecha y la hora
  # vienen en dos campos (`step=60`, sin segundos, `C30-08`); si el navegador
  # igual manda segundos, se tiran. Una fecha u hora que no se entiende deja la
  # que estaba, en vez de inventar una.
  def con(params)
    params = params.to_h.stringify_keys
    self.class.new(
      modo: params.fetch("modo", modo),
      tipo_envio_ids: params.key?("tipo_envio_ids") ? params["tipo_envio_ids"] : tipo_envio_ids,
      manifiesto_ids: params.key?("manifiesto_ids") ? params["manifiesto_ids"] : manifiesto_ids,
      disponible_en: leer_fecha_y_hora(params["fecha"], params["hora"]) || disponible_en
    )
  end

  def nuevas? = modo == "nuevas"
  def editar? = modo == "editar"

  # Los manifiestos que se ofrecen. En «nuevas», los de `Manifiesto.para_hoja`
  # de los servicios elegidos; en «editar», los que tienen pre-facturas
  # todavía sin avisar.
  def manifiestos_ofrecidos
    if editar?
      Manifiesto.tipo_oficial.where(estado: Manifiesto::ESTADOS_PARA_PRE_FACTURA, activo: true)
                .where(id: self.class.pre_facturas_editables.select(:manifiesto_id))
                .order(:numero)
    elsif tipo_envio_ids.any?
      Manifiesto.para_hoja(tipo_envio_ids)
    else
      Manifiesto.none
    end
  end

  # Las elegidas que todavía se ofrecen. Si un manifiesto salió de la lista
  # —se terminó de pre-facturar, o se cambiaron los servicios— deja de estar
  # elegido solo.
  def manifiestos_elegidos
    manifiestos_ofrecidos.where(id: manifiesto_ids)
  end

  # Lista para empezar a auditar: servicio, al menos un manifiesto y la fecha.
  def lista?
    nuevas? && tipo_envio_ids.any? && manifiestos_elegidos.exists?
  end

  # Las que «editar» ofrece: las que todavía no le avisaron al cliente
  # (`notificado_at`, el sello de PR-P.2), sin facturar ni anular, y que
  # salieron de la auditoría —**consolidando** (F8) o **programadas** (F9)—.
  # Una hecha a mano por `/pre_facturas/new` no tiene aviso que corregir.
  def self.pre_facturas_editables
    base = PreFactura.where(estado: "creado", notificado_at: nil).where.not(manifiesto_id: nil)
    base.where.not(consolidando_at: nil).or(base.where.not(notificar_at: nil))
  end

  def to_sesion
    { "modo" => modo, "tipo_envio_ids" => tipo_envio_ids, "manifiesto_ids" => manifiesto_ids,
      "disponible_en" => disponible_en.iso8601 }
  end

  private

  def leer_fecha_y_hora(fecha, hora)
    return nil if fecha.blank? && hora.blank?

    dia = fecha.present? ? Date.iso8601(fecha.to_s) : disponible_en.to_date
    h, m = if hora.to_s.match?(HORA)
             hora.to_s.split(":").first(2).map(&:to_i)
    else
             [ disponible_en.hour, disponible_en.min ]
    end
    dia.in_time_zone.change(hour: h, min: m)
  rescue Date::Error
    nil
  end
end
