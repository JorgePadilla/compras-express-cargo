# `RP-58` paso 2a · Un rol **adicional** de una persona.
#
# Yusef, 2026-08-30, sobre el caso que el enum de un solo rol no sabe nombrar:
# Michelle es *"Sub-Jefa de área de Caja y SAC"*, Bessy *"Supervisora de Caja y
# SAC"*. Antes eso obligaba a inventar un rol nuevo —y con él una columna más en
# la matriz de permisos— para cada combinación que apareciera.
#
# `users.rol` sigue siendo el **principal**: el que se muestra, el que alimenta
# los predicados del enum y el que decide el cortocircuito de admin. Esta tabla
# guarda los de más.
class RolDeUsuario < ApplicationRecord
  self.table_name = "roles_de_usuario"

  # La misma razón que en `PermisoDeRol`: quién le dio qué a quién y cuándo va a
  # ser la primera pregunta el día que alguien entre a una pantalla que no le
  # tocaba.
  has_paper_trail

  belongs_to :user

  validates :rol, presence: true, inclusion: { in: ->(_) { User.rols.keys } }
  validates :rol, uniqueness: { scope: :user_id }

  # **`admin` no puede ser un rol adicional**, y no es una restricción
  # cosmética. El cortocircuito de `can_access?` pregunta `Current.user.admin?`,
  # que es el predicado del enum sobre el rol **principal**. Si `admin` pudiera
  # entrar por acá habría dos verdades a la vez —`admin?` en falso y
  # «tiene el rol admin» en verdadero— y el cortocircuito se leería distinto
  # según quién preguntara. Admin se pone en el rol principal o no se pone.
  validate :admin_no_es_adicional

  # El principal ya lo tiene por definición: repetirlo acá haría creer que se le
  # dio algo cuando no se le dio nada.
  validate :no_repite_el_principal

  private

  def admin_no_es_adicional
    errors.add(:rol, "no puede ser adicional: admin va en el rol principal") if rol == "admin"
  end

  def no_repite_el_principal
    return if rol.blank? || user.nil? || rol != user.rol

    errors.add(:rol, "ya es el rol principal de esta persona")
  end
end
