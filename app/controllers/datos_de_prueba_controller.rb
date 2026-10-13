# La pantalla de datos de prueba: pre-alertas, volúmenes y manifiestos para
# recorrer el flujo en local y en staging. El porqué, en `DatosDePrueba`.
#
# **En producción no existe.** La ruta ya la corta (`config/routes.rb`), y el
# `before_action` lo repite por si alguien la saca de su `constraints`: una
# pantalla que crea datos falsos no puede depender de una sola guarda.
#
# Solo admin, y **sin llave en `PermisosDelSistema`** a propósito: una llave
# aparece como fila en /permisos, y esa pantalla sí existe en producción. Una
# fila de algo que en producción no hay es justo lo que Jorge pidió que no se
# viera.
class DatosDePruebaController < ApplicationController
  before_action :solo_fuera_de_produccion
  before_action :solo_admin

  def index
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @sucursales  = Sucursal.de_retiro
    @sueltos     = DatosDePrueba.paquetes.where(estado: %w[pre_alerta_estado recibido_miami], manifiesto_id: nil)
                                .includes(:cliente, :tipo_envio, :sucursal)
                                .order(id: :desc).limit(100)
    @manifiestos = Manifiesto.where(estado: "creado").order(id: :desc).limit(5)
  end

  def crear_pre_alertas
    cliente = buscar_cliente
    return if performed?

    generador = DatosDePrueba::PreAlertas.new(
      tipo_envio: TipoEnvio.find_by(id: params[:tipo_envio_id]),
      sucursal_retiro: Sucursal.find_by(id: params[:sucursal_id]),
      cantidad: params[:cantidad], volumenes: params[:volumenes],
      recibir: params[:recibir] == "1", cliente: cliente, user: Current.user
    )
    if (filas = generador.crear)
      cajas = filas.sum { |f| f.paquetes.size }
      redirect_to datos_de_prueba_path,
                  notice: "Lote #{generador.lote}: #{filas.size} pre-alerta(s) y #{cajas} caja(s)."
    else
      redirect_to datos_de_prueba_path, alert: generador.errores.to_sentence
    end
  end

  def crear_manifiesto
    armar = DatosDePrueba::ArmarManifiesto.new(
      tipo_envio_ids: params[:tipo_envio_ids], sucursal_entrega_ids: params[:sucursal_entrega_ids],
      cajas: params[:cajas], llenar: params[:llenar] == "1", user: Current.user
    )
    if (manifiesto = armar.crear)
      aviso = "Manifiesto de prueba #{manifiesto.numero} creado"
      aviso += armar.metidos.positive? ? ", con #{armar.metidos} paquete(s) adentro." : "."
      redirect_to manifiesto, notice: aviso
    else
      redirect_to datos_de_prueba_path, alert: armar.errores.to_sentence
    end
  end

  private

  # Opcional: el código de un cliente de verdad. Vacío, va el de prueba de la
  # sucursal (`DatosDePrueba.cliente_de_prueba`).
  def buscar_cliente
    codigo = params[:cliente_codigo].to_s.strip
    return nil if codigo.blank?

    Cliente.find_by("UPPER(codigo) = ?", codigo.upcase).tap do |cliente|
      redirect_to datos_de_prueba_path, alert: "No hay ningún cliente con el código #{codigo}." unless cliente
    end
  end

  def solo_fuera_de_produccion
    raise ActionController::RoutingError, "Not Found" unless DatosDePrueba.habilitados?
  end

  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless admin?
  end
end
