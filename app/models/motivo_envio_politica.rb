# C18-06: catálogo de por qué un paquete se mandó por la política de envío por
# defecto. Yusef, 2026-08-26: *"el paquete no llegó identificado con tipo de
# envío… ahora los enviamos nosotros de acuerdo a las políticas. Necesitamos
# una listita igual como la otra [retener]"*. Unos 100 paquetes al mes.
#
# `texto_al_cliente` es la frase que le llega al cliente —se compone en
# `paquetes.notas_al_cliente` y viaja en el correo de recibido—; `nombre` es
# cómo la ve el operario en la listita. Lo administra un admin en
# /motivos_envio_politica, como los motivos de retención.
class MotivoEnvioPolitica < ApplicationRecord
  has_paper_trail
  self.table_name = "motivos_envio_politica"

  has_many :paquete_motivos_envio_politica,
           class_name: "PaqueteMotivoEnvioPolitica",
           dependent: :restrict_with_error
  has_many :paquetes, through: :paquete_motivos_envio_politica, source: :paquete

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }
  validates :texto_al_cliente, presence: true

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :nombre) }

  def to_s
    nombre
  end
end
