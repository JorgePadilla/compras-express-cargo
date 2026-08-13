# Los grupos de clientes (la tabla `categoria_precios`).
#
# **Ya no tiene pantalla propia.** Jorge, por segunda vez: *"el área de categoría
# de precio, pensaría que se puede eliminar porque no le veo mucho valor… al
# menos que para vos sí lo tenga y definitivamente no se pueda eliminar"*.
#
# La tabla no se puede eliminar: los 8 grupos **son** las 8 columnas del Excel de
# Yusef y 28 de las 44 tarifas cuelgan de ellos. Pero la pantalla sí sobraba —un
# CRUD de un campo, en el sidebar, al lado de "Tabla de Servicios"—, así que la
# administración se mudó a `/servicios`, donde ya vive el precio.
#
# Lo que queda acá es el renombrar y el borrar, que se llaman desde ahí. Crear se
# hace tecleando el nombre en la tarifa (`ServiciosController`), que es el único
# momento en que un grupo sirve: uno sin tarifa no cobra nada.
class CategoriaPreciosController < ApplicationController
  before_action :require_admin
  before_action :set_categoria, only: %i[edit update destroy]

  # Las URLs viejas siguen vivas para los bookmarks, pero mandan a donde ahora se
  # administran los grupos. 302 y no 301: un 301 se le queda pegado al navegador
  # y no hay forma de despegarlo si mañana esto cambia.
  #
  # El detalle mostraba "qué cobra este grupo", que en /servicios está fila por
  # fila en la columna "Aplica a".
  def index
    redirect_to servicios_path
  end
  alias show index

  def new
    @categoria = CategoriaPrecio.new
  end

  def create
    @categoria = CategoriaPrecio.new(categoria_params)
    if @categoria.save
      redirect_to servicios_path, notice: "Grupo de clientes creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @categoria.update(categoria_params)
      redirect_to servicios_path, notice: "Grupo de clientes actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Se puede borrar un grupo que no usa nadie. Los dos
  # `dependent: :restrict_with_error` del modelo son la guarda real; acá lo que
  # importa es que, cuando no se puede, el mensaje diga **por qué**.
  #
  # Hasta `PR-C7.09` la ruta era `except: :destroy`: no había forma de sacar una
  # categoría del sistema, y las de la época vieja se quedaban para siempre.
  def destroy
    if @categoria.destroy
      redirect_to servicios_path, notice: "Grupo \"#{@categoria.nombre}\" eliminado."
    else
      redirect_to servicios_path,
                  alert: "No se puede eliminar \"#{@categoria.nombre}\". #{@categoria.motivo_no_borrable}"
    end
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  def set_categoria
    @categoria = CategoriaPrecio.find(params[:id])
  end

  # Solo el nombre. Una categoría agrupa clientes; el precio vive en `tarifas`
  # y se edita en /servicios, que es la única pantalla que cobra.
  def categoria_params
    params.require(:categoria_precio).permit(:nombre)
  end
end
