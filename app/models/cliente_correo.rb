# Un correo **de notificación** de un cliente. El de acceso es `clientes.email`.
#
# Yusef, 2026-08-19, mostrando una ficha: *"ella tiene dos correos, yo no le
# puedo crear una cuenta aquí porque tiene dos correos"*. Y cómo lo quiere:
# *"que tenga opción para varios correos y que tenga la opción de qué correo va a
# usar para manejar su cuenta"*.
#
# Por eso esto **no** compite con `clientes.email`: el de acceso sigue siendo
# uno solo —el que `authenticate_by` mira— y estos son a quién más avisarle.
# Elegir otro de acceso es intercambiarlos, no tener dos verdades.
class ClienteCorreo < ApplicationRecord
  belongs_to :cliente

  normalizes :correo, with: ->(c) { c.to_s.strip.downcase }

  validates :correo, presence: true,
                     format: { with: URI::MailTo::EMAIL_REGEXP },
                     uniqueness: { scope: :cliente_id, case_sensitive: false,
                                   message: "ya está en la lista" }

  # No puede repetir el de acceso: sería el mismo correo dos veces, y al
  # intercambiarlos quedaría duplicado.
  validate :no_repite_el_de_acceso

  private

  def no_repite_el_de_acceso
    return if correo.blank? || cliente.nil?
    return unless correo.casecmp?(cliente.email.to_s)

    errors.add(:correo, "ya es el correo de acceso")
  end
end
