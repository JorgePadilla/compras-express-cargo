# PR-9.b: la franja de contexto que vive a la derecha de /etiquetar y de
# /entrega_personal. Yusef (2026-08-01): "Jalar: Nombre → Tareas → y NOTAS.
# Tareas al lado derecho, checkbox, recopila el usuario."
#
# Se carga como turbo-frame: los controllers Stimulus de ambas pantallas le
# setean el `src` cuando el operario elige un cliente o cuando el tracking
# escaneado matchea una pre-alerta. Es de solo lectura salvo el checkbox de
# las tareas, que pega en TareasController#completar.
class PanelContextoController < ApplicationController
  before_action :authorize_panel

  def show
    @cliente = Cliente.find_by(id: params[:cliente_id])
    @tracking = params[:tracking].to_s.strip.upcase.presence

    return render :show if @cliente.nil?

    @tareas = Tarea.abiertas
                   .para_cliente(@cliente.id)
                   .visibles_para(Current.user)
                   .includes(:asignado_a)
                   .order(created_at: :asc)

    @paquete = paquete_del_tracking
    @notas_especiales = notas_especiales

    render :show
  end

  private

  def authorize_panel
    require_role(:supervisor_miami, :digitador_miami)
  end

  # El paquete solo existe si el tracking ya fue recibido antes o si venía de
  # una pre-alerta (`crear_paquete_esperado`). Cuando no existe, la franja
  # muestra únicamente cliente + tareas + notas permanentes.
  def paquete_del_tracking
    return nil if @tracking.blank?

    Paquete.where(cliente_id: @cliente.id)
           .where("UPPER(tracking) = :t OR UPPER(tracking_secundario) = :t", t: @tracking)
           .order(created_at: :desc)
           .first
  end

  # "Notas especiales" = las `instrucciones` que el cliente escribió en su
  # pre-alerta. Con tracking se acota a esa línea; sin tracking se muestran
  # las de sus pre-alertas todavía sin vincular, que es justo lo que el
  # digitador necesita saber antes de recibir.
  def notas_especiales
    scope = PreAlertaPaquete.joins(:pre_alerta)
                            .where(pre_alertas: { cliente_id: @cliente.id })
                            .where.not(instrucciones: [ nil, "" ])

    scope = if @tracking.present?
      scope.where("UPPER(pre_alerta_paquetes.tracking) = ?", @tracking)
    else
      scope.sin_vincular
    end

    scope.limit(5).pluck(:tracking, :instrucciones)
  end
end
