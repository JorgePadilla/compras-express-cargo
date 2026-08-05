# PR-10.a: la "tabla de servicios" que Yusef pidió — el CRUD que hasta ahora
# no existía. Los precios de `tipo_envios` se habían sembrado a mano:
#
#   "No tenés todavía la tabla de servicio. Creo que las puse a mano."
#   "TODOS ESTOS PRECIOS DEBEN PODER CAMBIAR."   — Yusef, 2026-08-02
#
# Se llama /servicios y no /tarifas porque para el negocio la unidad mental es
# el servicio (EXPRESS, CER, CEM…) y las tarifas son sus filas.
class ServiciosController < ApplicationController
  before_action :require_admin
  before_action :set_tarifa, only: %i[edit update destroy]

  def index
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @tarifas = Tarifa.includes(:tipo_envio, :categoria_precio, :cliente, :sucursal, :proveedor)
                     .to_a
                     .sort_by { |t| orden_de_lectura(t) }
                     .group_by(&:tipo_envio_id)
  end

  def new
    @tarifa = Tarifa.new(activo: true, moneda: "USD", desde_libras: 0,
                         aplica_minimo: true, tipo_envio_id: params[:tipo_envio_id])
    cargar_catalogos
  end

  def create
    @tarifa = Tarifa.new(tarifa_params)
    aplicar_minimo_con_isv

    if @tarifa.save
      redirect_to servicios_path, notice: "Tarifa creada."
    else
      cargar_catalogos
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    cargar_catalogos
  end

  def update
    @tarifa.assign_attributes(tarifa_params)
    aplicar_minimo_con_isv

    if @tarifa.save
      redirect_to servicios_path, notice: "Tarifa actualizada."
    else
      cargar_catalogos
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tarifa.destroy
    redirect_to servicios_path, notice: "Tarifa eliminada."
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  # PR-10.g: con los precios reales cargados esto pasó de 20 filas a ~60, y el
  # orden por id dejaba el precio de lista hasta abajo (en Postgres los NULL
  # ordenan al final). Se lee como una tabla de precios: primero el público,
  # después las excepciones, y dentro de cada una los escalones por peso con
  # la fila general antes que la de sucursal.
  def orden_de_lectura(t)
    nivel = if t.cliente_id          then 3
    elsif t.proveedor_id             then 2
    elsif t.categoria_precio_id      then 1
    else                                  0
    end

    # `downcase` para que "doTERRA" no caiga después de "VIP".
    [ nivel, t.categoria_precio&.nombre.to_s.downcase, t.desde_libras.to_f,
      t.sucursal&.nombre.to_s ]
  end

  def set_tarifa
    @tarifa = Tarifa.find(params[:id])
  end

  def cargar_catalogos
    @tipo_envios       = TipoEnvio.activos.order(:nombre)
    @categorias        = CategoriaPrecio.order(:nombre)
    @sucursales        = Sucursal.activas.ordered
    @proveedores       = Proveedor.activos.ordered
  end

  # Yusef razona en montos CON ISV ("el mínimo es 200 lempiras ya con ISV"),
  # pero la columna guarda el neto para no chocar con el ISV que se aplica al
  # totalizar. El form pregunta por el monto con impuesto y acá se convierte.
  def aplicar_minimo_con_isv
    return unless params[:tarifa].key?(:minimo_monto_con_isv)

    @tarifa.minimo_monto_con_isv = params[:tarifa][:minimo_monto_con_isv]
  end

  def tarifa_params
    params.require(:tarifa).permit(
      :tipo_envio_id, :categoria_precio_id, :cliente_id, :sucursal_id, :proveedor_id,
      :desde_libras, :hasta_libras, :precio_libra, :moneda,
      :minimo_moneda, :minimo_libras, :aplica_minimo, :incremento_libras,
      :activo, :notas
    )
  end
end
