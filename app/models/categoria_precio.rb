# Una categoría **agrupa clientes**. No guarda precios.
#
# Yusef, 2026-08-12: *"la categoría de precio confunde con la tabla de servicios,
# y está en lempiras la de categoría y el Excel está en dólares"*.
#
# Tenía razón por partida doble. La tabla llegó a tener `precio_libra_aereo`,
# `precio_libra_maritimo` y `precio_volumen`, con las vistas rotulándolos en
# lempiras — pero **no había columna `moneda`** y los números estaban de facto en
# dólares (el backfill de `create_tarifas.rb` los copió estampándoles `'USD'`).
# La etiqueta mentía.
#
# Y desde `PR-C7.06` esas columnas ya no las leía nadie: se podían editar y no
# cambiaba nada de lo que se cobra. Un formulario que promete configurar precios
# y no configura nada.
#
# Lo que sí hace la categoría, y es su única función, es entrar como **llave** en
# la cascada de `Tarifa.resolver` (`cliente → proveedor → categoría → lista`).
# El precio sale siempre de `tarifas.precio_libra`, que tiene su moneda explícita.
class CategoriaPrecio < ApplicationRecord
  # El audit log se queda: cambiarle la categoría a un grupo de clientes les
  # cambia lo que pagan, aunque el precio no viva acá.
  has_paper_trail
  has_many :clientes, dependent: :restrict_with_error
  has_many :tarifas, dependent: :restrict_with_error

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }

  # Lo que esta categoría cobra hoy, leído de donde de verdad vive el precio.
  # Vacío significa algo concreto y hay que decirlo en pantalla: sus clientes
  # pagan el precio de lista.
  def tarifas_vigentes
    tarifas.activas.includes(:tipo_envio, :sucursal).order("tipo_envios.nombre", :desde_libras)
  end

  # Una categoría se puede borrar cuando no la usa nadie.
  #
  # Los dos `dependent: :restrict_with_error` de arriba ya lo impiden a nivel de
  # base; esto existe para poder **decirlo antes**, en el botón, en vez de que el
  # usuario descubra la regla a fuerza de errores.
  def borrable?
    clientes.empty? && tarifas.empty?
  end

  # Por qué no se puede, en una frase que sirva tal cual en pantalla y en el
  # flash. Devuelve nil cuando sí se puede.
  def motivo_no_borrable
    return nil if borrable?

    partes = []
    partes << "#{clientes.count} cliente(s) asignado(s)" if clientes.any?
    partes << "#{tarifas.count} tarifa(s) cargada(s)"    if tarifas.any?

    "Tiene #{partes.to_sentence}."
  end

  # Las que declara la hoja de precios de Yusef vuelven a aparecer en la próxima
  # siembra: borrarlas es válido pero no es permanente, y conviene avisarlo antes
  # de que le den.
  def declarada_en_la_hoja?
    TarifasPropuesta2026::CATEGORIAS.any? { |c| c[:nombre] == nombre }
  end

  def to_s
    nombre
  end
end
