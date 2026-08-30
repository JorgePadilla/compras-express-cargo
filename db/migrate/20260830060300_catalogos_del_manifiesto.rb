# C21-08 · «Que un CRUD para todo, para todo lo del manifiesto».
#
# Yusef, 2026-08-29, especificando el manifiesto entero:
#
#   > "Si vos creás una [pantalla] donde yo pueda crear las empresas, los tipos
#   >  de envío que manejamos, la empresa que lo envía, qué consignatario somos
#   >  nosotros… que pueda yo crear estos, las cajas, los tamaños de las cajas,
#   >  en un solo [lugar]."
#   > "Como un portal, por decirte algo… pero que todo esté ahí, porque así uno
#   >  no tiene que andar buscando."
#
# Para qué, con nombre propio: poder decirle a Michelle *"andate al área donde
# dice empresa, agregame esta empresa que voy a usar"*. Es la misma filosofía de
# siempre — entre más cosas les dejemos crear, menos nos molestan.
#
# Tres de los cuatro catálogos ya existían de nombre y estaban **vacíos por
# dentro**: `Consignatario` y `TamanoCaja` son tablas sin una sola fila, sin
# pantalla y sin asociaciones; `EmpresaManifiesto` solo guarda el nombre. El
# cuarto —el tipo de envío del PROVEEDOR— no existía en ninguna forma, y por eso
# el formulario del manifiesto venía llenando ese campo con **nuestro** catálogo:
# la raíz de que Yusef dijera *"tengo que aprenderme que el tipo de envío del
# manifiesto es el del proveedor; aquí me pierdo"*.
class CatalogosDelManifiesto < ActiveRecord::Migration[8.0]
  def change
    # Lo que Yusef pidió que saliera impreso en el bloque del transportista:
    #   > "La dirección es tal, porque sale la dirección en la información de la
    #   >  empresa. Va la dirección y número, y si es posible hasta un encargado."
    # Y anotado a mano sobre el manifiesto impreso: «# tel» y «persona encargada».
    change_table :empresa_manifiestos, bulk: true do |t|
      t.string :direccion
      t.string :telefono
      t.string :encargado
    end

    # El tipo de envío del PROVEEDOR: «AEREO EXPRESS», «CKM MARITIMO». No tiene
    # nada que ver con el nuestro (CER, CKA, CEM, CKM, EXPRESS), y confundirlos
    # es justo lo que Yusef reclamó.
    create_table :tipo_envio_proveedores do |t|
      t.string  :nombre, null: false
      t.boolean :activo, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :tipo_envio_proveedores, :nombre, unique: true

    # Los dos catálogos que ya existían vacíos solo necesitan poder apagarse:
    # el equipo los va a llenar y a veces a jubilar, y borrar rompería los
    # manifiestos viejos que los apuntan.
    add_column :consignatarios, :activo, :boolean, null: false, default: true
    add_column :tamano_cajas,   :activo, :boolean, null: false, default: true
    add_column :tamano_cajas,   :position, :integer, null: false, default: 0
  end
end
