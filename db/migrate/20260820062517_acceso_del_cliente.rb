# El acceso del cliente al portal, administrable.
#
# Yusef, 2026-08-19: *"falta el sistema de usuario… lo del acceso de ellos"*.
# `Cliente` ya tenía `email` y `password_digest` y entra por el mismo formulario
# que el personal; lo que no existía era **dónde administrarlo**.
#
#   · `acceso_habilitado` — cortar el acceso sin dar de baja al cliente. Son dos
#     cosas distintas: `activo` significa "es cliente nuestro". Conflatirlas es
#     exactamente cómo este repo se rompe.
#
#     **Default `true`**: sin eso, el deploy que corra esta migración deja afuera
#     a todos los que hoy entran.
#
#   · `rtn` — al lado de `identidad`, los dos opcionales. *"Que se vaya
#     actualizando cuando ellos vayan pidiendo factura"*.
class AccesoDelCliente < ActiveRecord::Migration[8.0]
  def change
    add_column :clientes, :acceso_habilitado, :boolean, default: true, null: false
    add_column :clientes, :rtn, :string
  end
end
