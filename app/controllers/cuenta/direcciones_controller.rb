module Cuenta
  # C33-05 · «Mis Direcciones»: el casillero del cliente en Miami, uno por
  # servicio. En el sistema viejo era una pantalla del portal
  # (`/MiCuenta/Paquetes/MisDirecciones`), y en este el link del menú apuntaba
  # a `#` desde el principio. Los correos del casillero dicen lo mismo
  # (`DireccionesDelCasillero`).
  class DireccionesController < BaseController
    def show
      @direcciones = DireccionesDelCasillero.new(current_cliente)
    end
  end
end
