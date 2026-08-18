class PreAlertaPaquete < ApplicationRecord
  belongs_to :pre_alerta
  belongs_to :paquete, optional: true
  # PR-9.a: las `instrucciones` que el cliente escribe se materializan como
  # Tarea para que el digitador las vea (y las pueda marcar) en la franja de
  # /etiquetar. `nullify` para no borrar la evidencia de una tarea ya hecha
  # si después se elimina la línea de la pre-alerta.
  has_many :tareas, dependent: :nullify

  validates :tracking, presence: true, uniqueness: { scope: :pre_alerta_id, case_sensitive: false }
  # allow_blank: true avoids double error ("can't be blank" + format) when tracking is empty;
  # presence: true above already handles the blank case.
  validates :tracking, format: { with: /\A[A-Z0-9-]+\z/, message: "solo permite letras, números y guiones" },
                       allow_blank: true
  validates :descripcion, presence: true

  scope :sin_vincular, -> { where(paquete_id: nil) }
  scope :vinculados, -> { where.not(paquete_id: nil) }

  # PR-C6.21: la misma escalera que `Paquete.buscar_escaneado`, del lado de la
  # pre-alerta. Va acá también porque el paquete de Miami y su pre-alerta se
  # buscan con el MISMO escaneo: si un lado tolera el código largo del carrier
  # y el otro no, la pistola encuentra la pre-alerta y pierde el paquete (o al
  # revés) sobre el mismo bulto.
  def self.buscar_escaneado(valor)
    termino = valor.to_s.strip.upcase
    return none if termino.blank?

    exacto = all.where("UPPER(pre_alerta_paquetes.tracking) = ?", termino)
    return exacto if exacto.exists?

    return none if termino.length < Paquete::ESCANEO_LARGO_MINIMO

    all.where("UPPER(pre_alerta_paquetes.tracking) = RIGHT(?, LENGTH(pre_alerta_paquetes.tracking))", termino)
       .where("LENGTH(pre_alerta_paquetes.tracking) >= ?", Paquete::ESCANEO_LARGO_MINIMO)
  end

  # La fecha nace puesta, no se llena recién al validar.
  #
  # Jorge: *"pongamos la fecha que se está haciendo, por defecto en el campo"*.
  # `set_default_fecha` ya la ponía —o sea que se guardaba bien— pero el campo
  # salía **vacío** en la pantalla: el operario no sabía qué fecha iba a quedar,
  # y el dato parecía faltante.
  #
  # Va como default del atributo y no como `after_initialize` a propósito: la
  # API de `attribute` aplica el default **solo a instancias nuevas**. Un
  # registro viejo con `fecha` nula se sigue leyendo nulo, en vez de que
  # cualquier lectura le invente una fecha de hoy que nunca tuvo.
  #
  # Con esto alcanza para los dos lugares donde nace una fila: el
  # `pre_alerta_paquetes.build` del controller y el `PreAlertaPaquete.new` del
  # `<template>` de filas nuevas.
  attribute :fecha, :date, default: -> { Date.current }

  # Se queda como red: si alguien manda la fecha en blanco explícitamente —un
  # request a mano, un import— igual entra con la de hoy.
  before_validation :set_default_fecha
  before_validation :normalize_tracking

  after_create :crear_paquete_esperado
  after_update :sync_paquete_esperado
  after_save   :sync_tarea_desde_instrucciones
  before_destroy :anular_paquete_esperado
  # `prepend: true` es obligatorio: el `dependent: :nullify` de `has_many
  # :tareas` registra su propio before_destroy al declararse la asociación
  # (arriba), así que sin prepend correría primero y nos dejaría sin
  # `pre_alerta_paquete_id` con el cual encontrar la tarea abierta.
  before_destroy :descartar_tarea_abierta, prepend: true

  after_destroy_commit :soft_delete_pre_alerta_if_empty

  # Links unlinked pre_alerta_paquetes by tracking to a given paquete.
  # Advances parent pre_alerta estado to "recibido" if still in pre_alerta state.
  # Returns number of rows linked.
  #
  # PR-D1.e: ahora matchea contra el tracking PRINCIPAL del paquete y el
  # SECUNDARIO (cuando existe). Yusef pidió esto porque muchos paquetes
  # llegan con 2 trackings: el cliente pre-alerta con uno, el paquete
  # físico llega con el otro. Sin este match dual, la vinculación falla.
  def self.link_tracking!(tracking, paquete)
    argument_tracking  = tracking
    primary_tracking   = paquete.tracking
    secondary_tracking = paquete.tracking_secundario

    candidatos = [ argument_tracking, primary_tracking, secondary_tracking ]
                   .compact_blank
                   .map { |t| t.to_s.strip.upcase }
                   .uniq
    return 0 if candidatos.empty?

    rows = sin_vincular.where("UPPER(tracking) IN (?)", candidatos)
    pre_alerta_ids = rows.pluck(:pre_alerta_id).uniq
    # PR-9.a: hay que capturar los ids ANTES del update_all — después de
    # asignar `paquete_id` la relación `sin_vincular` deja de matchearlos.
    pap_ids = rows.pluck(:id)
    count = rows.update_all(paquete_id: paquete.id)

    if count > 0
      # Las tareas nacidas de `instrucciones` colgaban solo del cliente (o
      # del paquete esperado). Al llegar el paquete físico las reapuntamos
      # para que aparezcan también en su historial.
      Tarea.where(pre_alerta_paquete_id: pap_ids).update_all(paquete_id: paquete.id)

      pre_alertas = PreAlerta.where(id: pre_alerta_ids)

      # PR-D2: snapshot de notas_grupo de pre-alerta consolidada al
      # paquete (notas_consolidacion). Solo si el paquete no las tiene
      # ya (no sobrescribir si admin/sac las editó).
      if paquete.notas_consolidacion.blank?
        notas = pre_alertas.where(consolidado: true)
                          .where.not(notas_grupo: [ nil, "" ])
                          .pluck(:notas_grupo)
                          .compact_blank
                          .uniq
        if notas.any?
          paquete.update_column(:notas_consolidacion, notas.join("\n\n"))
        end
      end

      pre_alertas.where(estado: "pre_alerta").find_each do |pa|
        pa.update!(estado: "recibido")
      end
    end

    count
  end

  private

  def set_default_fecha
    self.fecha ||= Date.current
  end

  def normalize_tracking
    self.tracking = tracking.strip.upcase if tracking.present?
  end

  def soft_delete_pre_alerta_if_empty
    pa = pre_alerta
    return unless pa
    return if pa.deleted_at.present?
    pa.soft_delete! if pa.pre_alerta_paquetes.reload.empty?
  end

  # Al crear un PAP, materializamos un Paquete "esperado" en estado
  # `pre_alerta_estado` para que aparezca de una vez en /paquetes.
  # Cuando el paquete físico llegue a Miami, EtiquetarController lo
  # encuentra por tracking y lo transiciona en lugar de crear uno nuevo.
  def crear_paquete_esperado
    return if paquete_id.present?

    paquete = Paquete.create!(
      cliente_id: pre_alerta.cliente_id,
      tipo_envio_id: pre_alerta.tipo_envio_id,
      tracking: tracking,
      descripcion: descripcion,
      estado: "pre_alerta_estado",
      user: Current.user,
      pre_alerta: true,
      # La retención marcada desde la pre-alerta viaja al paquete esperado, así
      # el que lo recibe en Miami ya lo ve marcado sin tener que acordarse.
      retener_miami: retener_miami
    )
    update_columns(paquete_id: paquete.id)
  end

  # Si el cliente edita el PAP (cambia tracking o descripcion) y el
  # paquete asociado todavía está en `pre_alerta_estado`, sincronizamos.
  # Una vez recibido en Miami, el operador es dueño del paquete — no
  # tocamos.
  def sync_paquete_esperado
    return unless paquete_id.present?
    # `retener_miami` entra acá también: si se marca DESPUÉS de crear la
    # pre-alerta, el paquete esperado tiene que enterarse igual. Sin esto, la
    # bandera solo funcionaba al crear.
    return unless saved_change_to_tracking? || saved_change_to_descripcion? ||
                  saved_change_to_retener_miami?

    p = paquete
    return unless p && p.estado == "pre_alerta_estado"

    p.update!(tracking: tracking, descripcion: descripcion, retener_miami: retener_miami)
  end

  # PR-9.a: las instrucciones del cliente ("el celular por Express, la ropa
  # por marítimo") se vuelven una Tarea real para que el digitador las vea
  # con checkbox en la franja de /etiquetar en vez de que se pierdan en un
  # textarea que nadie abre.
  #
  # Idempotente por `pre_alerta_paquete_id`: re-guardar la pre-alerta no
  # duplica la tarea. `bloquea_avance: false` es deliberado — ver el
  # comentario en la migración 20260801150000.
  def sync_tarea_desde_instrucciones
    return unless saved_change_to_instrucciones?

    tarea = Tarea.find_or_initialize_by(pre_alerta_paquete_id: id, origen: "pre_alerta")

    if instrucciones.blank?
      # El cliente borró las instrucciones: retiramos la tarea si nadie la
      # completó todavía. Si ya está hecha, se conserva como evidencia.
      tarea.destroy if tarea.persisted? && !tarea.realizada?
      return
    end

    # No reabrimos algo que el operario ya marcó como hecho.
    return if tarea.persisted? && tarea.realizada?

    tarea.assign_attributes(
      cliente_id:     pre_alerta.cliente_id,
      paquete_id:     paquete_id,
      titulo:         "Instrucciones del cliente — #{tracking}",
      descripcion:    instrucciones,
      departamento:   "miami",
      bloquea_avance: false
    )
    tarea.save!
  end

  # Si se elimina la línea de la pre-alerta, la instrucción dejó de aplicar.
  # Borramos la tarea solo si sigue abierta; las completadas quedan (con
  # `pre_alerta_paquete_id` nulificado por el `dependent: :nullify`).
  def descartar_tarea_abierta
    tareas.abiertas.where(origen: "pre_alerta").destroy_all
  end

  # Si el PAP se elimina (vía nested-attributes _destroy o cascade de
  # PreAlerta destroy) y el paquete sigue esperando, lo anulamos en vez
  # de destruirlo — preserva audit trail y evita FK hell.
  def anular_paquete_esperado
    return unless paquete_id.present?
    p = paquete
    return unless p && p.estado == "pre_alerta_estado"

    p.update!(estado: "anulado")
  end
end
