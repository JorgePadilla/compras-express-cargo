# C21-04 · Armar las casas de un manifiesto.
#
# La pantalla vieja tiene dos botones —**Solo Agregar (F5)** y
# **Agregar/Imprimir (F9)**— y una tabla con las casas armadas. Acá va la mitad
# de datos; la impresión de la 4×6 llega en `PR-M4`.
#
# El tamaño pre-definido pre-llena las medidas y **el cursor va al peso**:
# *"te ponen solo el cursor a peso, porque es lo que le vas a meter a ingresar,
# que es lo que hace falta"*. Las medidas quedan editables — *"le modifican una
# medida, porque la cortan… le decimos «EH cortada»"*.
class CajasManifiestoController < ApplicationController
  before_action :authorize_manifiestos
  before_action :set_manifiesto
  before_action :set_caja, only: %i[update destroy etiqueta]

  # C21-05 · La 4×6 del bulto. Yusef escribió a mano sobre la etiqueta impresa
  # lo que le faltaba —**«Falta el número del manifiesto»**— y, junto al código
  # de barras, para qué sirve: *«se escanea al recibir en HN → actualiza estatus
  # de paquetes de ENVIADO → ADUANA»*.
  def etiqueta
    @cajas = [ @caja ]
    render "manifiestos/cajas/etiqueta", layout: "etiqueta_4x6"
  end

  # Todas las del manifiesto de un tiro, con el mismo patrón de
  # `PaquetesController#etiquetas_combinadas`: N etiquetas en una sola pestaña,
  # una por página.
  def etiquetas
    @cajas = @manifiesto.cajas.ordenadas
    render "manifiestos/cajas/etiqueta", layout: "etiqueta_4x6"
  end

  def create
    @caja = @manifiesto.cajas.new(caja_params)
    @caja.user = Current.user

    if @caja.save
      @manifiesto.recalculate_totals!
      redirect_to @manifiesto, notice: "Caja #{@caja.letra} agregada."
    else
      redirect_to @manifiesto, alert: @caja.errors.full_messages.to_sentence
    end
  end

  def update
    if @caja.update(caja_params)
      @manifiesto.recalculate_totals!
      redirect_to @manifiesto, notice: "Caja #{@caja.letra} actualizada."
    else
      redirect_to @manifiesto, alert: @caja.errors.full_messages.to_sentence
    end
  end

  def destroy
    letra = @caja.letra
    @caja.destroy!
    @manifiesto.recalculate_totals!
    # La letra NO se devuelve: `ultima_letra` solo sube. Si se reusara, la
    # etiqueta ya impresa y pegada al bulto apuntaría a otra caja.
    redirect_to @manifiesto, notice: "Caja #{letra} eliminada."
  end

  private

  def authorize_manifiestos
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:manifiestos)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:manifiesto_id])
  end

  def set_caja
    @caja = @manifiesto.cajas.find(params[:id])
  end

  def caja_params
    params.require(:caja_manifiesto).permit(:tamano_caja_id, :alto, :largo, :ancho, :peso, :numero_doc)
  end
end
