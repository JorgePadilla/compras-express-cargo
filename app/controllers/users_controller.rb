class UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: [ :show, :edit, :update ]

  def index
    @users = User.order(created_at: :desc)
    @users = @users.buscar(params[:q]) if params[:q].present?
    @users = @users.page(params[:page]).per(25)
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

  def user_params
    params.require(:user).permit(
      :nombre, :email_address, :password, :password_confirmation,
      :rol, :ubicacion, :activo
    )
  end
end
