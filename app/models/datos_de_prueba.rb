# Datos de prueba para recorrer el flujo en local y en staging: pre-alertas,
# paquetes recibidos en Miami (con sus volúmenes) y manifiestos.
#
# Jorge, 2026-10-13, después de armar a mano diez pre-alertas desde la consola
# de Render para escanear en un manifiesto: *"can we create a testing
# dashboard, were we can create things like this manifests base on tipo de
# envios, pre-alertas volumenes for testing"*. Y: *"this should only be
# available on local and staging"* · *"it should not be visible on production"*.
#
# ── Dónde existe ───────────────────────────────────────────────────────────
#
# `habilitados?` es la única pregunta, y la contesta `Fiscal.produccion?`, que
# **falla cerrado**: con `RAILS_ENV=production`, todo es producción salvo el
# host exacto de staging. Staging y producción corren las dos con
# `RAILS_ENV=production`, así que preguntar por el entorno no alcanza; y
# preguntar «¿es el host de producción?» fallaba abierto (el porqué, en
# `Fiscal.produccion?`). Un staging mal configurado se queda sin la pantalla,
# que es la falla barata.
#
# La misma pregunta cierra las tres puertas: la ruta (en producción no existe:
# 404), el link de la barra y la tarjeta del Home.
#
# ── Lo que crea ────────────────────────────────────────────────────────────
#
# Va por los mismos caminos que el sistema: la pre-alerta deja su paquete
# esperado, y «recibir» lo pasa a `recibido_miami` como `/etiquetar`
# (`DatosDePrueba::PreAlertas`). El manifiesto se crea como el formulario
# (`DatosDePrueba::ArmarManifiesto`). **No se manda ningún correo**: el aviso
# de recibido lo manda el controller de `/etiquetar`, no el modelo.
#
# Todo tracking empieza con `PRUEBA`, así se encuentra en `/paquetes`.
module DatosDePrueba
  PREFIJO = "PRUEBA".freeze
  # Cuántas pre-alertas de una vez, y cuántas cajas por paquete. Alcanza para
  # llenar un manifiesto sin que un dedo de más cree mil.
  MAX_PRE_ALERTAS = 50
  MAX_VOLUMENES   = 10
  MAX_CAJAS       = 10

  module_function

  def habilitados?
    !Fiscal.produccion?
  end

  # Los paquetes que se crearon acá: el tracking con la forma exacta que les da
  # `DatosDePrueba::PreAlertas` (`PRUEBA` + lote de 10 dígitos + 2). Con un
  # `LIKE 'PRUEBA%'` entraba también un `PRUEBA1` que alguien tecleó a mano en
  # staging, y «llenar» se lo habría llevado a un manifiesto de prueba.
  def paquetes
    Paquete.where("paquetes.tracking ~ ?", "^#{PREFIJO}[0-9]{12}$")
  end

  # El cliente de prueba de una sucursal: uno por sucursal donde retira, con el
  # código `PRUEBA-TGU`. Así las pre-alertas no caen en la cuenta de un cliente
  # de verdad —en staging hay cuentas reales, y la pre-alerta se ve en su portal—.
  def cliente_de_prueba(sucursal)
    Cliente.find_or_create_by!(codigo: "#{PREFIJO}-#{sucursal.codigo}") do |c|
      c.nombre = "Cliente de Prueba"
      c.apellido = sucursal.nombre
      c.sucursal_retiro = sucursal
      c.activo = true
    end
  end

  def entero(valor, minimo:, maximo:)
    Integer(valor.to_s, exception: false)&.clamp(minimo, maximo) || minimo
  end
end
