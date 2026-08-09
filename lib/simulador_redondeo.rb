# PR-C6.19: cuánto cambia la facturación si se prende el cobro en medias libras.
#
# **Solo lectura.** No escribe nada, no toca `incremento_libras`, no crea
# documentos. Se corre en staging contra los paquetes reales y la salida se le
# lleva a Yusef.
#
# Ya no es una compuerta: él dio la orden ("préndanlo ya", RP-03) sin pedir el
# número antes. Sigue sirviendo para tres cosas — verificar después de activar,
# darle evidencia al contador, y ser el insumo con el que por fin revise la
# hoja 2 del Excel (RP-16, "no ha revisado").
#
# Usa **el motor real** (`Tarifa.resolver` + `cobro_para` + `peso_facturable`),
# no una reimplementación de la regla: si el simulador y la facturación
# difieren, el informe miente y es peor que no tenerlo.
class SimuladorRedondeo
  INCREMENTO = BigDecimal("0.5")

  Fila = Struct.new(:paquete, :antes, :despues, :peso, :peso_redondeado, :segmento,
                    keyword_init: true) do
    def delta
      despues - antes
    end
  end

  def initialize(paquetes: nil)
    @paquetes = paquetes || Paquete.where.not(peso_cobrar: nil)
                                   .includes(:cliente, :tipo_envio, :sucursal)
  end

  def filas
    @filas ||= @paquetes.filter_map { |p| simular(p) }
  end

  # Agrupado por qué le pasa a cada paquete, porque el impacto **no es
  # uniforme** y un promedio solo lo escondería.
  def resumen
    por_segmento = filas.group_by(&:segmento)

    SEGMENTOS.filter_map do |clave, titulo|
      grupo = por_segmento[clave]
      next if grupo.blank?

      {
        segmento: titulo,
        paquetes: grupo.size,
        delta_total: grupo.sum(&:delta).round(2),
        delta_promedio: (grupo.sum(&:delta) / grupo.size).round(2),
        peor_caso: grupo.max_by { |f| f.delta.abs }
      }
    end
  end

  def total
    filas.sum(&:delta).round(2)
  end

  SEGMENTOS = {
    minimo:      "Caen en el mínimo del servicio — no cambian",
    sin_cambio:  "El peso ya venía en media libra — no cambian",
    baja:        "Bajan: la fracción estaba dentro de la tolerancia (.01–.09)",
    sube:        "Suben: la fracción redondea hacia arriba",
    frontera:    "Bajan fuerte: el redondeo los pasa al escalón más barato"
  }.freeze

  private

  def simular(paquete)
    peso = paquete.peso_cobrar
    return nil if peso.blank? || peso.to_d <= 0

    antes = cobro(paquete, peso.to_d)
    return nil if antes.nil?

    # El redondeo sale del motor, no de una fórmula copiada acá.
    redondeado = Tarifa.new(incremento_libras: INCREMENTO).peso_facturable(peso)
    despues = cobro(paquete, redondeado)
    return nil if despues.nil?

    Fila.new(
      paquete: paquete, antes: antes[:lps], despues: despues[:lps],
      peso: peso.to_d, peso_redondeado: redondeado,
      segmento: clasificar(antes, despues, peso.to_d, redondeado)
    )
  end

  # Todo se compara en Lempiras: las tarifas están en dólares y los mínimos en
  # Lempiras, así que sumar los subtotales crudos mezclaría monedas.
  def cobro(paquete, peso)
    tarifa = Tarifa.resolver(
      tipo_envio: paquete.tipo_envio, peso: peso,
      cliente: paquete.cliente, sucursal: paquete.sucursal
    )
    return nil if tarifa.nil?

    resultado = tarifa.cobro_para(peso)
    resultado.merge(
      tarifa: tarifa,
      lps: CurrencyAware.convertir(resultado[:subtotal], de: resultado[:moneda], a: "LPS")
    )
  end

  def clasificar(antes, despues, peso, redondeado)
    return :minimo     if antes[:aplico_minimo] && despues[:aplico_minimo]
    return :sin_cambio if redondeado == peso
    # Cambió de escalón: el redondeo lo empujó al tramo de arriba, que es más
    # barato por libra. Es el caso que PR-C6.18 vino a arreglar.
    return :frontera   if antes[:tarifa] != despues[:tarifa]
    return :baja       if redondeado < peso

    :sube
  end
end
