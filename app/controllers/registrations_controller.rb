class RegistrationsController < ApplicationController
  include ClienteAuthentication

  allow_unauthenticated_access
  allow_unauthenticated_cliente_access

  layout "application"

  def new
    @cliente = Cliente.new
    @sucursales_retiro = Sucursal.de_retiro
  end

  def create
    @cliente = Cliente.new(registration_params)
    # PR-C7.38: acá también se teclea el nombre, así que también van los tres
    # ítems. `PR-C7.33` puso la regla en `/clientes` y se olvidó de esta, que es
    # la pantalla gemela — y la de afuera: es pública, no pide autenticación y
    # está linkeada desde el login.
    #
    # El porqué de Yusef aplica más todavía acá, donde nadie del mostrador está
    # mirando: *"tiene que poner mínimo tres ítems… imaginate cuántos Jorge
    # Padilla hay"*.
    #
    # Los 9.000 importados siguen sin enterarse: la regla la enciende esta
    # bandera, y solo la encienden las dos pantallas donde alguien teclea.
    @cliente.exigir_nombre_completo = true
    # C29-03 · La gemela de `/clientes#create`: dónde retira se pregunta al
    # abrir el casillero, y acá es el cliente mismo el que lo abre.
    @cliente.exigir_sucursal_retiro = true
    @cliente.activo = true

    if @cliente.save
      start_new_cliente_session_for(@cliente)
      redirect_to cuenta_root_path, notice: "Bienvenido a Compras Express Cargo! Tu cuenta ha sido creada exitosamente."
    else
      @sucursales_retiro = Sucursal.de_retiro
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:cliente).permit(:nombre, :apellido, :email, :telefono, :sucursal_retiro_id,
                                    :password, :password_confirmation)
  end
end
