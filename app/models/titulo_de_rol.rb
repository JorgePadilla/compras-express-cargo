# `RP-58` paso 2b · Cómo se lee un rol, cuando alguien le cambió el nombre.
#
# Yusef: *"editar el título del rol y lo que ellos puedan y no puedan"*. Y el
# porqué, que es el mismo de toda la serie: *"hay cositas que se nos van a
# escapar"* y *"no es lo mismo tu sistema con el otro"* — los puestos de la
# empresa no se llaman como los nombró el código.
#
# **La fila existe solo si alguien renombró ese rol.** Sin fila manda
# `User::ROL_DESCRIPTIONS`, así que una base vacía se comporta igual que antes de
# que esto existiera, y borrar la fila es «volver al nombre del sistema». Es la
# misma decisión que `PermisoDeRol`, por las mismas razones.
#
# **El código no se toca.** `supervisor_caja` sigue siendo `supervisor_caja` en
# el enum, en `PermisosDelSistema.politica` y en cada constante `*_ROLES`.
# Renombrar el título **no cambia lo que el rol puede hacer**.
class TituloDeRol < ApplicationRecord
  self.table_name = "titulos_de_rol"

  # Un rol renombrado y después vuelto a renombrar es exactamente la clase de
  # cosa por la que alguien pregunta «¿y esto desde cuándo se llama así?».
  has_paper_trail

  validates :rol, presence: true,
                  inclusion: { in: ->(_) { User.rols.keys } },
                  uniqueness: true
  validates :titulo, presence: true

  # El mapa de lo renombrado, en una consulta: `{ "cajero" => "Caja" }`.
  #
  # `rol_label` se llama por fila en el listado de usuarios, en la bitácora del
  # paquete y en los dropdowns de quién autoriza. Una consulta por llamada sería
  # el mismo problema que `Current.permisos` ya tuvo que resolver, así que se
  # memoiza por request — `CurrentAttributes` se limpia solo entre uno y otro.
  def self.mapa
    Current.titulos ||= pluck(:rol, :titulo, :descripcion).to_h { |rol, titulo, desc|
      [ rol, { label: titulo, descripcion: desc } ]
    }
  end

  # Lo que se guarda cuando alguien renombra, y lo que se borra cuando lo deja
  # como el sistema lo trae. Devuelve cuántas filas cambiaron.
  #
  # Un título igual al del sistema **no deja fila**: si la dejara, cambiar el
  # nombre por defecto en el código no se vería nunca, tapado en silencio por una
  # fila que dice lo mismo que decía el código el día que se guardó.
  def self.guardar(entradas)
    cambios = 0

    User.rols.keys.each do |rol|
      entrada = entradas[rol] || {}
      titulo = entrada[:titulo].to_s.strip
      descripcion = entrada[:descripcion].to_s.strip
      fila = find_by(rol: rol)

      if titulo.blank? || (titulo == User.titulo_del_sistema(rol) &&
                           descripcion == User.descripcion_del_sistema(rol).to_s)
        cambios += 1 if fila&.destroy
      else
        atributos = { titulo: titulo, descripcion: descripcion.presence }
        if fila.nil?
          create!(atributos.merge(rol: rol))
          cambios += 1
        elsif fila.titulo != titulo || fila.descripcion != descripcion.presence
          fila.update!(atributos)
          cambios += 1
        end
      end
    end

    # Defensa, no necesidad: hoy `update` redirige y el límite de request ya
    # resetea `CurrentAttributes`. Está por si algún día renderiza en vez de
    # redirigir — ahí la pantalla mostraría los nombres viejos recién guardados.
    Current.titulos = nil
    cambios
  end
end
