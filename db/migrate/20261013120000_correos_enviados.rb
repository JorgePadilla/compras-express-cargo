# PR-C31.10 · La bitácora de los correos que salen (prerrequisito de `C31-20`).
#
# Yusef, 2026-10-12, pidiendo la vista del cliente para SAC: *"todos los
# pre-alertas, todos los paquetes, todas las facturas, **todos los correos
# enviados, lo que falló**"*. Hasta acá el sistema no guardaba nada de lo que
# mandaba: el correo salía (o no) desde la cola y no quedaba rastro.
#
# Una fila por intento de entrega, la escribe `ApplicationMailer`. Solo se
# agrega: no se edita ni se versiona.
class CorreosEnviados < ActiveRecord::Migration[8.0]
  def change
    create_table :correos_enviados do |t|
      # Nulo cuando el correo no es de un cliente (el aviso interno de cajas
      # faltantes, la clave de un usuario) o no se lo pudo reconocer. Si se
      # borra el cliente, el registro queda sin él: un log no frena nada.
      t.references :cliente, foreign_key: { on_delete: :nullify }, index: false
      t.string :mailer, null: false
      t.string :accion, null: false
      t.string :para
      t.string :asunto
      t.string :estado, null: false
      t.text :error
      t.datetime :enviado_at, null: false
      t.timestamps
    end

    add_index :correos_enviados, %i[cliente_id created_at]
    add_check_constraint :correos_enviados, "estado IN ('enviado', 'fallido')",
                         name: "correos_enviados_estado"
  end
end
