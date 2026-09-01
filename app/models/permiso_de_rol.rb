# `RP-58` · Una excepción al mapa de permisos que trae el código.
#
# La fila existe **solo cuando alguien movió esa celda** desde la pantalla. Sin
# fila manda `PermisosDelSistema.politica`, así que una base vacía se comporta
# igual que antes de que esto existiera.
class PermisoDeRol < ApplicationRecord
  self.table_name = "permisos_de_rol"

  # Quién le quitó qué a quién y cuándo va a ser la primera pregunta el día que
  # alguien se quede sin una pantalla que usaba ayer.
  has_paper_trail

  validates :rol, presence: true, inclusion: { in: ->(_) { User.rols.keys } }
  validates :seccion, presence: true,
                      inclusion: { in: ->(_) { SeccionesDelSistema::TODAS.keys.map(&:to_s) } }
  validates :seccion, uniqueness: { scope: :rol }
  validates :permitido, inclusion: { in: [ true, false ] }

  # `admin` no lleva filas: su acceso es un cortocircuito en `can_access?`, no
  # una celda. Una fila que le negara algo no haría nada —hay un test que lo
  # fija— y guardarla haría creer que sí.
  validate :admin_no_lleva_excepciones

  # `:permisos` y `:usuarios` no se mueven desde la pantalla: concedérselas a
  # un rol es regalarle todo lo demás en el siguiente clic.
  validate :seccion_editable

  # Las excepciones de **los** roles de una persona, en una consulta, anidadas
  # por rol: `{ "cajero" => { "caja" => true }, "sac" => { "ventas" => false } }`.
  #
  # `RP-58` paso 2a: anidado y no aplanado a propósito. Aplanarlo obliga a
  # elegir un ganador cuando dos roles dicen cosas distintas de la misma
  # sección, y esa elección **no se puede hacer acá**: quien sabe resolverla es
  # `can_access?`, que suma rol por rol. Un mapa plano se veía más cómodo y
  # perdía en silencio el permiso que el otro rol sí daba.
  def self.mapa_para(roles)
    lista = Array(roles).compact_blank.map(&:to_s)
    return {} if lista.empty?

    where(rol: lista)
      .pluck(:rol, :seccion, :permitido)
      .each_with_object({}) { |(rol, seccion, permitido), mapa|
        (mapa[rol] ||= {})[seccion] = permitido
      }
  end

  private

  def admin_no_lleva_excepciones
    errors.add(:rol, "no admite excepciones: el admin entra por cortocircuito") if rol == "admin"
  end

  def seccion_editable
    return if seccion.blank? || PermisosDelSistema.editable?(seccion)

    errors.add(:seccion, "no se puede mover desde la pantalla")
  end
end
