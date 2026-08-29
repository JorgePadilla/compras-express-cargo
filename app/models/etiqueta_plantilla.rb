# C19-06: la plantilla de la etiqueta, editable por Yusef desde
# /ajustes_etiqueta. "¿Vos no tenés en el sistema donde yo pueda cambiarlas
# yo? El tamaño… a mí me habían dado esto [en el legacy] para no molestar."
#
# Es un singleton: sin registro rige el **default de fábrica**, que vive como
# constante en `Definicion` — la original ES el código, así que «restaurar la
# original» (que en el legacy era "tengo que grabar las originales") es borrar
# el registro, y el deploy —que solo migra, nunca siembra— no necesita nada.
#
# paper_trail guarda quién y cuándo; el historial se muestra como resumen,
# nunca el diff del JSON crudo.
class EtiquetaPlantilla < ApplicationRecord
  has_paper_trail

  def self.singleton
    first_or_initialize
  end

  # La definición que rige la impresión, siempre usable: sin registro, con el
  # registro roto o con valores basura, `Definicion` clampa y cae al default.
  # El path de impresión jamás tira 500 ni manda basura a la Dymo.
  def self.vigente
    Definicion.new(first&.definicion)
  rescue StandardError => e
    Rails.logger.warn "[etiqueta] plantilla ilegible, rige la de fábrica: #{e.message}"
    Definicion.new(nil)
  end

  def self.restaurar_original!
    first&.destroy!
  end

  # El paquete del preview: 100% en memoria (nada se guarda, nada consulta),
  # determinístico, y con TODOS los opcionales puestos — el preview tiene que
  # mostrar la etiqueta más llena posible, que es la que puede no caber.
  # `fecha_recibido_miami` va explícita: un Paquete sin persistir no tiene
  # `created_at` y la fecha saldría vacía.
  def self.paquete_de_muestra
    Paquete.new(
      tracking: "TBA333187639911",
      tracking_secundario: "1Z999AA10123456784",
      numero_recepcion: "RMIA2608000123",
      numero_caja: 1, cantidad_paquetes: 2,
      fecha_recibido_miami: Time.current,
      driver: "Marvin Lopez",
      tercero_nombre: "Maria Fernanda Lopez",
      # C20-08: la muestra es de entrega personal y SIN pagar a propósito. El
      # renglón «NO PAGADO» solo sale en esas —y es el estado más ancho—, así
      # que sin esto el preview medía una etiqueta que no es la más llena y su
      # «Cabe ✓» habría dejado pasar tamaños que desbordan cada etiqueta de EP.
      prepagado_miami: false,
      cliente: Cliente.new(codigo: "C6", nombre: "Kenia Isabel", apellido: "Maya Rodriguez",
                           ciudad: "San Pedro Sula", departamento: "Cortés"),
      sucursal: Sucursal.new(nombre: "San Pedro Sula"),
      tipo_envio: TipoEnvio.new(codigo: "exp", nombre: "EXPRESS"),
      proveedor: Proveedor.new(codigo: "AMZ", tipo: "entrega_personal"),
      user: User.new(iniciales: "DM", nombre: "Digitador Miami")
    )
  end
end
