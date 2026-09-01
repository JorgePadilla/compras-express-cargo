# `RP-58` paso 2b · La pantalla donde se renombran los puestos.
#
# Yusef: *"siempre necesitamos que nosotros podamos editar el rol y los roles que
# tiene [cada puesto]… **editar el título del rol** y lo que ellos puedan y no
# puedan"*. Lo segundo es `/permisos`; esto es lo primero.
#
# **No es un CRUD**, y por eso no tiene `new` ni `destroy`: los roles no se
# crean ni se borran. Sus códigos viven en el enum de `User`, en el `case` de
# `PermisosDelSistema.politica` y en cada constante `*_ROLES` — inventar uno
# desde una pantalla dejaría un rol que ninguna regla conoce. Acá se renombran
# los nueve que hay.
#
# **El admin sí aparece**, al revés que en `/permisos`. Allá se lo excluye porque
# no se le pueden quitar accesos; acá se trata de cómo se lee su puesto, y eso sí
# es suyo para cambiar.
class RolesController < ApplicationController
  before_action :solo_admin

  def show
    @roles = User.rols.keys
  end

  def update
    cambios = TituloDeRol.guardar(entradas)

    redirect_to roles_path, notice: aviso(cambios)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to roles_path, alert: "No se guardó: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def solo_admin
    return if can_access?(:roles)

    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion."
  end

  # `{ "cajero" => { titulo: "Caja", descripcion: "…" } }`, con las llaves como
  # símbolos porque es lo que `TituloDeRol.guardar` espera.
  def entradas
    params.fetch(:roles, {}).permit!.to_h.transform_values do |v|
      { titulo: v["titulo"], descripcion: v["descripcion"] }
    end
  end

  def aviso(cambios)
    return "No había nada que cambiar." if cambios.zero?

    "Títulos actualizados: #{cambios} cambio(s)."
  end
end
