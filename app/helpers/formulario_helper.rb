# El label de un campo, con su «Obligatorio» o su «(opcional)» al lado.
#
# Estaba copiado en las dos pantallas de pre-alerta —admin y portal— y con dos
# tipografías distintas. Es el mismo texto y la misma jerarquía: va en un solo
# lado. Ver `FormSectionComponent` para la razón larga.
module FormularioHelper
  # `obligatorio` acepta `true` o un texto: el tracking no dice solo
  # "Obligatorio" sino "Obligatorio (Aquí NO va el Número de Orden)", que es una
  # corrección que Yusef pidió expresamente y que no se puede perder al unificar.
  def etiqueta_de_campo(texto, obligatorio: false, ayuda: nil)
    partes = [ texto ]

    if obligatorio
      aclaracion = obligatorio == true ? "Obligatorio" : obligatorio
      partes << tag.span(aclaracion, class: "text-xs font-normal text-red-500 dark:text-red-400 ml-1")
    elsif ayuda.present?
      partes << tag.span(ayuda, class: "text-xs font-normal text-gray-500 dark:text-gray-400 ml-1")
    end

    safe_join(partes, " ")
  end

  # Las clases del `<label>` que envuelve a eso. Navy en claro y gris claro en
  # oscuro — el navy sobre fondo oscuro es ilegible (1.69:1), y el gold se
  # reserva para los títulos de sección: un formulario entero en dorado cansa.
  def clases_de_etiqueta
    "block text-sm font-semibold text-cec-navy dark:text-gray-100 mb-1.5"
  end

  # El de las celdas de tabla: mismo lenguaje, más apretado. La fila del
  # editor de admin mete siete columnas en el ancho de la pantalla.
  def clases_de_input_compacto
    clases_de_input.sub("px-3 py-2.5", "px-2 py-1.5")
  end

  # Un dato que se muestra pero no se edita — la fecha de la pre-alerta, que la
  # pone el servidor.
  #
  # Va como `<span>` y NO como `<input readonly>` a propósito: un input
  # readonly sigue entrando en el orden de tabulación, y Jorge pidió que el Tab
  # lo salte. En Miami trabajan solo con teclado ("usamos las manos para
  # trabajar"), así que un campo que no se puede editar y roba un tab es un
  # estorbo en cada paquete.
  #
  # Se ve como un campo para que se lea igual que sus vecinos, pero apagado.
  def clases_de_campo_sellado
    "block w-full rounded-lg border border-gray-200 dark:border-gray-700 " \
      "bg-gray-50 dark:bg-gray-900 text-gray-500 dark:text-gray-400 px-3 py-2.5 text-sm"
  end

  # El input de texto estándar de estas pantallas.
  def clases_de_input
    "block w-full rounded-lg border border-gray-300 dark:border-gray-600 " \
      "bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 px-3 py-2.5 text-sm " \
      "focus:outline-none focus:ring-2 focus:ring-cec-teal focus:border-cec-teal"
  end
end
