# `RP-58` · La pantalla donde se mueve el mapa de permisos.
#
# Yusef: *"sería mejor si se lograra [una pantalla] donde nosotros podamos
# editar los permisos de los roles, de acuerdo al puesto"*, y el costo de no
# tenerla: *"te vamos a estar molestando con que necesitamos quitar y poner… y
# te vamos a tener en ese relajo"*.
#
# Guarda **solo lo que se movió**. Una celda que coincide con el código no deja
# fila, así que destildar y volver a tildar la deja como estaba — y borrar la
# fila es la operación de deshacer.
class PermisosController < ApplicationController
  before_action :solo_admin

  def show
    @roles = roles_editables
    @por_grupo = SeccionesDelSistema.por_grupo
    @excepciones = PermisoDeRol.all.index_by { |p| [ p.rol, p.seccion ] }
  end

  def update
    marcadas = params.fetch(:permisos, {})
    resultado = GuardarPermisos.new(marcadas, roles: roles_editables).call

    if resultado.errores.any?
      redirect_to permisos_path, alert: "No se guardó: #{resultado.errores.join(' · ')}"
    else
      redirect_to permisos_path, notice: aviso(resultado)
    end
  end

  private

  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:permisos)
  end

  # El admin no se dibuja como columna editable: su acceso es un cortocircuito
  # en `can_access?`, no una fila. Mostrarlo con casillas haría creer que se le
  # puede quitar algo.
  def roles_editables
    User.rols.keys - [ "admin" ]
  end

  def aviso(resultado)
    if resultado.cambios.zero?
      "No había nada que cambiar."
    else
      "Permisos actualizados: #{resultado.cambios} cambio(s). " \
        "#{resultado.excepciones} sección(es) fuera de lo que trae el código."
    end
  end
end
