# C33-05 · Los tres correos del casillero de la planilla de Yusef (C33-01,
# filas 5 a 7). Los tres llevan las mismas direcciones
# (`DireccionesDelCasillero`), las que el cliente ve en «Mis Direcciones»:
#
# - `bienvenida`: al crear el casillero, desde /clientes o desde /registro.
# - `informacion_actualizada`: *"es el mismo de casillero nuevo con todos los
#   nuevos que hemos cambiado"*, y *"es un botón en el perfil de cliente"*.
# - `informacion_general`: *"cuando queramos enviarle información a un correo
#   de una persona no cliente aún"*. Va desde SAC, sin cliente.
#
# El texto es provisional: *"te puedo dar una plantilla a mi gusto"* (Yusef,
# 2026-10-24). Cuando llegue, cambian las vistas y no esto.
class CasilleroMailer < ApplicationMailer
  def bienvenida(cliente)
    @cliente = cliente
    @direcciones = DireccionesDelCasillero.new(cliente)
    return if cliente.email.blank?

    mail to: cliente.email, subject: "Bienvenido a Compras Express Cargo: su casillero #{cliente.codigo}"
  end

  def informacion_actualizada(cliente)
    @cliente = cliente
    @direcciones = DireccionesDelCasillero.new(cliente)
    return if cliente.email.blank?

    mail to: cliente.email, subject: "Las direcciones de su casillero #{cliente.codigo}"
  end

  def informacion_general(correo, nombre: nil)
    @nombre = nombre.presence
    @direcciones = DireccionesDelCasillero.new
    return if correo.blank?

    mail to: correo, subject: "Su casillero en Miami con Compras Express Cargo"
  end
end
