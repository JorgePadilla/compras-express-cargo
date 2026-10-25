# C33-05 · Las direcciones del casillero: a dónde tiene que mandar el cliente
# sus compras para que lleguen a su nombre.
#
# Es lo que mostraba «Mis Direcciones» en el sistema viejo (docs/05, «7. Mis
# Direcciones»): la bodega de Miami una vez por servicio, porque la «LÍNEA 2»
# le dice a la bodega qué servicio pidió (`tipo_envios.linea_2_casillero`, que
# se edita en /servicios). Lo usan la página del portal y los correos del
# casillero, para que no digan cosas distintas.
#
# La dirección de Miami es la misma del Warehouse Receipt
# (`config.x.warehouse_receipt.issuing_company`): no se copia otra vez.
#
# Sin cliente (el correo de «información general» a alguien que todavía no es
# cliente) el nombre queda como instrucción.
class DireccionesDelCasillero
  Bloque = Struct.new(:titulo, :descripcion, :campos, keyword_init: true) do
    # Lo que se copia de un golpe: una línea por campo, como se pega en el
    # formulario de la tienda.
    def texto = campos.map { |etiqueta, valor| "#{etiqueta}: #{valor}" }.join("\n")
  end

  SIN_CLIENTE = "SU CÓDIGO DE CASILLERO Y NOMBRE COMPLETO".freeze

  def initialize(cliente = nil)
    @cliente = cliente
  end

  def nombre
    return SIN_CLIENTE unless @cliente

    [ @cliente.codigo, @cliente.nombre_completo ].compact_blank.join(" ").upcase
  end

  def bloques = de_miami + de_otras_bodegas

  private

  def de_miami
    # Aéreos primero y marítimos después, como en el sistema viejo.
    TipoEnvio.activos.where.not(linea_2_casillero: [ nil, "" ]).order(:modalidad, :nombre).map do |tipo|
      Bloque.new(titulo: "Miami · #{tipo.nombre}", descripcion: descripcion(tipo),
                 campos: campos_de_miami(tipo.linea_2_casillero))
    end
  end

  MODALIDADES = { "aereo" => "Aéreo", "maritimo" => "Marítimo" }.freeze

  def descripcion(tipo)
    servicio = [ MODALIDADES[tipo.modalidad], (tipo.con_reempaque? ? "con reempaque" : "sin reempaque") ].compact.join(" ")
    [ servicio, tipo.sla ].compact_blank.join(" · ")
  end

  def campos_de_miami(linea_2)
    miami = Rails.application.config.x.warehouse_receipt.issuing_company
    [
      [ "Nombre", nombre ],
      [ "Línea 1", miami.street.upcase ],
      [ "Línea 2", linea_2 ],
      [ "Ciudad", miami.city.upcase ],
      [ "Estado", miami.state.upcase ],
      [ "Código postal", miami.postal_code ],
      [ "Teléfono", miami.phone ],
      [ "País", miami.country.upcase ]
    ]
  end

  # México (y la que se agregue) solo cuando alguien le cargó la dirección en
  # /sucursales: sin ella no hay nada que mandar.
  def de_otras_bodegas
    otras = Sucursal.de_recepcion.where("sucursales.ubicacion IS DISTINCT FROM 'miami'").where.not(direccion: [ nil, "" ])
    otras.map do |sucursal|
      Bloque.new(titulo: sucursal.nombre, descripcion: nil,
                 campos: [ [ "Nombre", nombre ], [ "Dirección", sucursal.direccion.squish ] ])
    end
  end
end
