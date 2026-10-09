class UsersController < ApplicationController
  before_action :solo_admin
  before_action :set_user, only: [ :show, :edit, :update ]
  before_action :cargar_sucursales, only: [ :new, :create, :edit, :update ]

  def index
    @users = User.order(created_at: :desc)
    @users = @users.buscar(params[:q]) if params[:q].present?
    @users = @users.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to @user, notice: "Usuario creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    filtered = user_params
    filtered = filtered.except(:password, :password_confirmation) if filtered[:password].blank?
    # PR-13.c: el PIN se deja como está si el campo viene vacío — igual que la
    # contraseña. Si el admin escribe uno nuevo, se reinicia `pin_cambiado_at`:
    # vuelve a ser "el que puso el admin" hasta que el supervisor lo cambie.
    if filtered[:pin].blank?
      filtered = filtered.except(:pin, :pin_confirmation)
    else
      @user.pin_cambiado_at = nil
    end

    if @user.update(filtered)
      redirect_to @user, notice: "Usuario actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  # Todas las activas, no solo las que reciben: un cajero trabaja en SPS.
  def cargar_sucursales
    @sucursales = Sucursal.activas.ordered
  end

  def user_params
    params.require(:user).permit(
      :nombre, :iniciales, :email_address, :password, :password_confirmation,
      :rol, :ubicacion, :activo, :sucursal_id,
      # PR-13.c: el admin asigna el PIN inicial; el supervisor lo cambia desde
      # /mi_pin. Ver el comentario en `User#pin_sin_cambiar?`.
      :pin, :pin_confirmation,
      # `RP-58` paso 2a · Los roles de más. Array, y por eso va al final: en
      # `permit` un array se declara con la llave apuntando a `[]`.
      roles_adicionales_lista: []
    )
  end
  # `RP-58` · Va por `can_access?` y no por `require_admin`: toda regla de rol
  # tiene que pasar por el mismo lugar, o una pantalla de permisos diría que se
  # puede algo que este controller después niega.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:usuarios)
  end
end
