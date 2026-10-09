# `RP-58` · Guarda el mapa de permisos como **excepciones**.
#
# La pantalla manda el estado completo de la grilla —qué está tildado— y esto lo
# compara contra `PermisosDelSistema.politica`:
#
#   · coincide con el código → **se borra** la fila, si la había. Volver al
#     default no deja rastro que después haya que mantener.
#   · difiere → se guarda la excepción.
#
# Así el tamaño de la tabla es el tamaño de lo que alguien decidió cambiar, y no
# 9 × 39 filas que nadie tocó.
class GuardarPermisos
  Resultado = Struct.new(:cambios, :excepciones, :errores, keyword_init: true)

  def initialize(marcadas, roles:)
    @marcadas = marcadas
    @roles = roles
  end

  def call
    cambios = 0
    errores = []

    PermisoDeRol.transaction do
      roles_enviados.each do |rol|
        secciones_editables.each do |seccion|
          deseado = tildada?(rol, seccion)
          cambios += 1 if aplicar(rol, seccion, deseado, errores)
        end
      end
      raise ActiveRecord::Rollback if errores.any?
    end

    Resultado.new(cambios: errores.any? ? 0 : cambios,
                  excepciones: PermisoDeRol.count, errores: errores)
  end

  private

  # Solo los roles que el formulario mandó de verdad.
  #
  # Sin esto, un rol ausente del payload se lee como «todo destildado» y le
  # borra **todos** los accesos. La pantalla manda un marcador oculto por
  # columna justamente para que «vine y no marqué nada» se distinga de «no
  # vine» — es el mismo truco que Rails usa con el hidden antes de un checkbox.
  def roles_enviados
    @roles.select { |rol| @marcadas.key?(rol) }
  end

  def secciones_editables
    SeccionesDelSistema::TODAS.keys.select { |s| PermisosDelSistema.editable?(s) }
  end

  def tildada?(rol, seccion)
    @marcadas.dig(rol, seccion.to_s).present?
  end

  # Devuelve true si algo cambió de verdad.
  def aplicar(rol, seccion, deseado, errores)
    fila = PermisoDeRol.find_by(rol: rol, seccion: seccion.to_s)
    codigo = PermisosDelSistema.politica(rol, seccion)

    if deseado == codigo
      # Volvió al default: la excepción sobra.
      return false unless fila

      fila.destroy!
      return true
    end

    return false if fila&.permitido == deseado

    fila ||= PermisoDeRol.new(rol: rol, seccion: seccion.to_s)
    fila.permitido = deseado
    return true if fila.save

    errores << "#{rol}/#{seccion}: #{fila.errors.full_messages.to_sentence}"
    false
  end
end
