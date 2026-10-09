# Cuenta botones escritos a mano en las vistas.
#
# PR-BTN.2. Lo usan DOS lados y por eso vive acá y no adentro del test:
#
#   · `test/lint/botones_test.rb` — el trinquete que impide que entren nuevos
#   · `bin/rails botones:presupuesto` — imprime el hash listo para pegar
#
# Si cada uno tuviera su copia del conteo, bajar la línea base daría un número
# distinto del que el test espera y el trinquete se abandonaría a la semana.
module BotonesCrudos
  module_function

  # Los comentarios NO cuentan. `entrega_personal/new.html.erb` tiene un
  # `<%# ... ButtonComponent ... %>` explicando un truco de sintaxis, y sin
  # esto se contaría como un botón.
  def sin_comentarios(src)
    src.gsub(/<%#.*?%>/m, "").gsub(/<!--.*?-->/m, "")
  end

  # Cuántos botones escritos a mano hay en este ERB.
  #
  # Se cuenta por TAG con `/m`, no por línea: 21 de los `link_to` estilados del
  # sistema están partidos en varias líneas, y una regex por línea los pierde
  # (el primer conteo de la auditoría dio 254 contra 275 reales).
  def contar(src)
    s = sin_comentarios(src)

    n  = s.scan(/<button\b/).size
    n += s.scan(/\bbutton_to\b/).size
    n += s.scan(/\bf\.submit\b/).size
    n += s.scan(/\bsubmit_tag\b/).size
    n + links_con_forma_de_boton(s)
  end

  # Un `link_to` cuenta como botón si tiene padding horizontal, vertical **y**
  # borde redondeado. Exigir `rounded` es lo que evita los falsos positivos: un
  # link con padding y sin esquina redondeada es una fila de tabla o un renglón
  # de menú, no un botón.
  def links_con_forma_de_boton(src)
    src.scan(/<%=?.*?%>/m).count do |tag|
      tag.include?("link_to") &&
        tag =~ /\bpx-\d/ && tag =~ /\bpy-[\d.]/ && tag =~ /\brounded/
    end
  end

  # Los valores de `class` de este ERB, vengan del atributo HTML o del `class:`
  # de un helper de Rails. Se devuelven por elemento, no concatenados: para
  # detectar "blanco sobre teal" las dos clases tienen que caer en el MISMO
  # elemento — si no, cualquier tarjeta teal con un hijo blanco daría falso
  # positivo.
  def valores_de_clase(src)
    s = sin_comentarios(src)

    s.scan(/class="([^"]*)"/m).flatten +
      s.scan(/class:\s*"([^"]*)"/m).flatten +
      s.scan(/class:\s*'([^']*)'/m).flatten
  end

  # Texto blanco sobre el teal de marca: 2.46:1, cuando WCAG AA pide 4.5:1.
  # `cec-teal-dark` tampoco salva (3.39:1). La regla del sistema es
  # `text-cec-navy-dark` encima del teal — 6.69:1.
  def contar_blanco_sobre_teal(src)
    valores_de_clase(src).count do |valor|
      valor =~ /\bbg-cec-teal(-dark)?\b/ && valor =~ /\btext-white\b/
    end
  end

  # Dónde puede haber un botón crudo.
  #
  # `app/components` entró en `PR-C7.17`: hasta entonces el censo solo miraba
  # `app/views`, así que **el markup que se mueve a un componente dejaba de
  # lintearse**. Es un agujero que se agranda solo — cada refactor a
  # ViewComponent le saca vistas de encima al lint— y se notó al mudar el
  # repetidor de cajas: el presupuesto nombraba el componente y el censo no lo
  # veía, o sea que su × podía haber sido cualquier cosa.
  RUTAS = [ "app/views/**/*.erb", "app/components/**/*.erb" ].freeze

  # Todas las vistas y componentes, con su cuenta. `{ruta_relativa => n}`, sin
  # los ceros.
  def censo(&contador)
    contador ||= method(:contar)

    RUTAS.flat_map { |g| Dir.glob(Rails.root.join(g)) }.sort.each_with_object({}) do |ruta, acc|
      n = contador.call(File.read(ruta))
      next if n.zero?

      acc[ruta.sub("#{Rails.root}/", "")] = n
    end
  end
end
