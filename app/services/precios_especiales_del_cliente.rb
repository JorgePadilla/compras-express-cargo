require "bigdecimal"

# El "megacuadro" de la ficha del cliente (`A7-26`, `PR-C7.15`).
#
# Yusef, Conversación 7:
#
#   > "Ese precio especial para un cliente **debería estar en el cliente**, digo
#   >  yo. Entro al cliente y le pongo el precio especial."
#   > "Le doy descuento en CER y en CEM, **pero no le doy descuento en EXPRESS**."
#   > "Tiene que ser un **megacuadro** para el cliente… un cuadro donde vaya con
#   >  todas esas, como seleccionamos."
#
# Y la tensión que Manalo puso sobre la mesa —*"eso de tener un montón de precios
# siempre es mala idea"*— que Yusef resolvió así: *"en este negocio vos negociás
# tarifas… estandarizar la mayoría y crearle botones para las excepciones"*.
#
# **Es una vista sobre `tarifas`, no una tabla nueva.** Lee y escribe las filas
# de nivel cliente, que ya son el primer nivel de `Tarifa.resolver`. Guardar los
# precios del cliente en otro lado volvería a dejar dos fuentes de verdad para el
# mismo número, que es exactamente `A7-25` — la que se acaba de cerrar.
#
# Y contesta lo del "descuento" sin inventar un mecanismo: el descuento **es** el
# precio especial. Por eso cada fila sabe contra qué se está negociando
# (`#precio_sin_excepcion`) y el cuadro muestra la diferencia.
class PreciosEspecialesDelCliente
  # El peso con el que se pregunta "¿cuánto paga por libra?". Una libra: sirve
  # para leer el precio del primer tramo, que es lo que el cuadro compara.
  PESO_DE_REFERENCIA = 1

  # Una fila del cuadro: un servicio, lo que paga hoy, y su excepción si tiene.
  Fila = Struct.new(:tipo_envio, :propia, :escalones, :vigente, :sin_excepcion,
                    :solo_volumetrico, keyword_init: true) do
    # Una escalera no cabe en una celda. Si este cliente ya tiene tramos
    # cargados para el servicio, la fila se muestra en solo lectura y se edita
    # en la Tabla de Servicios.
    def escalonado? = escalones.size > 1 || escalones.any? { |t| !plana?(t) }

    def plana?(t) = t.hasta_libras.blank? && t.desde_libras.to_d.zero?

    def precio_especial = propia&.precio_libra

    def minimo_con_isv = propia&.minimo_monto_con_isv

    def aplica_minimo? = propia.nil? || propia.aplica_minimo

    # Cuánto más barato es el precio especial que lo que pagaría sin él. nil
    # cuando no hay excepción o no hay contra qué comparar.
    def descuento_pct
      return nil if propia.nil? || sin_excepcion.nil?

      base = sin_excepcion.precio_libra.to_d
      return nil if base.zero?

      ((propia.precio_libra.to_d - base) / base * 100).round
    end
  end

  def initialize(cliente)
    @cliente = cliente
    @errores = []
  end

  attr_reader :errores

  # Lo que se pinta. Una fila por servicio activo, en el orden que le den.
  # Funciona también con un cliente sin guardar: el formulario de alta lo pinta
  # para que se pueda marcar el cobro por volumen desde el principio —Yusef:
  # *"es lo que le creamos al cliente, **cuando creamos el cliente**"*—. Ahí no
  # hay tarifas propias todavía, y "paga hoy" sale del precio de lista.
  def filas(tipo_envios)
    propias = @cliente.persisted? ? Tarifa.where(cliente_id: @cliente.id).group_by(&:tipo_envio_id) : {}
    solo_vol = @cliente.tipo_envio_solo_volumetrico_ids.to_set

    tipo_envios.map do |te|
      del_cliente = propias[te.id] || []

      Fila.new(
        tipo_envio: te,
        propia: del_cliente.find { |t| t.hasta_libras.blank? && t.desde_libras.to_d.zero? },
        escalones: del_cliente,
        vigente: resolver(te),
        sin_excepcion: resolver(te, ignorar_precio_del_cliente: true),
        solo_volumetrico: solo_vol.include?(te.id)
      )
    end
  end

  # Aplica lo que mandó el formulario.
  #
  # `datos` viene como `{ "<tipo_envio_id>" => { "precio" =>, "minimo_con_isv" =>,
  # "aplica_minimo" => } }`. Devuelve true si guardó todo.
  #
  # Va en una transacción: o queda todo el cuadro o no queda nada. Media
  # negociación aplicada es peor que ninguna.
  def aplicar(datos)
    return true if datos.blank?

    @errores = []
    propias = Tarifa.where(cliente_id: @cliente.id).group_by(&:tipo_envio_id)

    ActiveRecord::Base.transaction do
      datos.each do |tipo_envio_id, celda|
        aplicar_celda(tipo_envio_id.to_i, celda, propias[tipo_envio_id.to_i] || [])
      end

      raise ActiveRecord::Rollback if @errores.any?
    end

    @errores.empty?
  end

  private

  def resolver(tipo_envio, ignorar_precio_del_cliente: false)
    Tarifa.resolver(tipo_envio: tipo_envio, peso: PESO_DE_REFERENCIA,
                    cliente: @cliente, ignorar_precio_del_cliente:)
  end

  # La tabla de decisión completa:
  #
  #   precio con valor + no hay fila   → crea
  #   precio con valor + fila plana    → actualiza
  #   precio vacío     + fila plana    → borra (se le quita la excepción)
  #   precio vacío     + no hay fila   → nada
  #   cualquier cosa   + escalonado    → error, no se pisa la escalera
  def aplicar_celda(tipo_envio_id, celda, del_cliente)
    plana = del_cliente.find { |t| t.hasta_libras.blank? && t.desde_libras.to_d.zero? }
    escalonado = del_cliente.size > 1 || (del_cliente.any? && plana.nil?)
    precio = celda[:precio].to_s.strip

    # Un formulario viejo no puede aplastar en silencio una escalera que alguien
    # construyó mientras tanto. Es error, no salto.
    if escalonado
      return if precio.blank? && del_cliente.none? # imposible, pero explícito

      @errores << "#{nombre_de(tipo_envio_id)}: tiene #{del_cliente.size} tramos cargados. " \
                  "Los precios escalonados se editan en la Tabla de Servicios."
      return
    end

    if precio.blank?
      # Vaciar el precio **quita** la excepción; los mínimos de esa fila no
      # significan nada sin un precio que cobrar.
      plana&.destroy!
      return
    end

    tarifa = plana || Tarifa.new(cliente_id: @cliente.id, tipo_envio_id: tipo_envio_id,
                                 desde_libras: 0, moneda: "USD")
    tarifa.precio_libra = precio
    tarifa.aplica_minimo = ActiveModel::Type::Boolean.new.cast(celda[:aplica_minimo]) != false
    tarifa.minimo_monto_con_isv = celda[:minimo_con_isv]
    # `minimo_moneda` es obligatoria cuando hay monto, y acá el cuadro entero
    # habla en dólares.
    tarifa.minimo_moneda = tarifa.minimo_monto.present? ? "USD" : nil

    return if tarifa.save

    @errores << "#{nombre_de(tipo_envio_id)}: #{tarifa.errors.full_messages.to_sentence}"
  end

  def nombre_de(tipo_envio_id)
    @nombres ||= TipoEnvio.pluck(:id, :codigo).to_h
    @nombres[tipo_envio_id].to_s.upcase.presence || "Servicio ##{tipo_envio_id}"
  end
end
