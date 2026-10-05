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
    # C23-05 · Cuando la 4×6 se abrió sola después de agregar, no hay pestaña
    # que cerrar: hay que **devolver** la que se llevó. `volver=1` y no la URL
    # de vuelta en el parámetro, que sería un redirect abierto de regalo.
    @despues_de_imprimir = manifiesto_path(@manifiesto) if params[:volver] == "1"
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

      # C23-05 · *"Después de que le damos a agregar, de un solo… te las
      # imprimo"* · *"sí, que le tire la que está haciendo de un solo"*.
      #
      # Va por **redirect y no por popup**: esta impresión nace de un POST, no
      # de un clic, y el `window.open` que no nace de un gesto lo bloquea
      # Chrome sin decir nada —el mismo tropiezo de `/entrega_personal`, donde
      # *"un gesto del usuario alcanza para un popup, no para dos"*—. La 4×6 se
      # lleva ESTA pestaña, se imprime sola y `@despues_de_imprimir` la
      # devuelve al manifiesto. Sin popup no hay bloqueador que valga.
      if params[:print] == "true"
        redirect_to etiqueta_manifiesto_caja_path(@manifiesto, @caja, print: true, volver: 1)
        return
      end

      redirect_to @manifiesto, notice: "Caja #{@caja.letra} agregada."
    else
      redirect_to @manifiesto, alert: @caja.errors.full_messages.to_sentence
    end
  end

  # C28-05 · Corregir una caja ya armada. La acción existía desde `C21-04` y
  # ninguna pantalla la llamaba; ahora el lápiz de cada fila la carga en el
  # mismo formulario de arriba. Yusef: *"marqué quiero una EH y al final… la
  # hice en una E… le corté un pedazo"* · *"la voy a agregar sin peso porque
  # voy a empacar… después le voy a agregar el peso"*. Y por qué no alcanza con
  # borrar y volver a armar: *"ya los he visto confundirse"*.
  #
  # «Guardar e imprimir» reimprime la 4×6 con los números nuevos, por el mismo
  # redirect que usa `create` (sin popup, que Chrome bloquea sin gesto).
  def update
    if @caja.update(caja_params)
      @manifiesto.recalculate_totals!
      if params[:print] == "true"
        redirect_to etiqueta_manifiesto_caja_path(@manifiesto, @caja, print: true, volver: 1)
        return
      end

      redirect_to @manifiesto, notice: "Caja #{@caja.letra} actualizada."
    else
      redirect_to @manifiesto, alert: @caja.errors.full_messages.to_sentence
    end
  end

  def destroy
    letra = @caja.letra
    @caja.destroy!
    @manifiesto.recalculate_totals!
    # C28-06 · La letra **sí** vuelve: la próxima caja la toma. Si su
    # etiqueta ya estaba pegada, hay que despegarla, y el aviso lo dice.
    redirect_to @manifiesto, notice: "Caja #{letra} eliminada. Si su etiqueta ya estaba pegada, despegala: " \
                                     "la próxima caja va a ser la #{CajaManifiesto.siguiente_letra_de(@manifiesto)}."
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
    params.require(:caja_manifiesto).permit(:tamano_caja_id, :alto, :largo, :ancho, :peso)
  end
end
