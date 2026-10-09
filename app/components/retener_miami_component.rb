# «Retener en Miami» — el único lugar donde se escribe ese control.
#
# Jorge, sobre `/pre_alertas/new`: *"retener en Miami debería comportarse igual
# que el de etiquetar y entrega personal, debería ser el mismo componente"*. Al
# ir a buscarlo para reusarlo, no existía: había **cuatro pantallas y cuatro
# respuestas distintas**.
#
#   · `/etiquetar` tenía el bloque completo — casilla, modal, motivos y nota.
#   · El form de `/paquetes` tenía **una copia**, y ya había divergido:
#     consultaba `MotivoRetencion` **adentro de la vista**, y los rótulos y los
#     botones no eran los mismos.
#   · `/entrega_personal` no tenía **nada**, aunque su controller carga los
#     motivos y permite `retener_miami` y `motivo_retencion_ids` desde siempre.
#     Cableado muerto: la intención estaba, el marcado nunca se escribió.
#   · La pre-alerta tenía solo la casilla, y **solo al crear** — la pantalla de
#     editar no la mostraba, así que marcarla mal era irreversible.
#
# ── Por qué componente y no partial ───────────────────────────────────────
#
# Por lo mismo que `CajasPesoMedidasComponent`: un `initialize` de kwargs no se
# puede confundir con "definido pero nil", y acá el bloque se pinta en cinco
# archivos con form builders distintos. Un local que no llega es un modal que
# sale vacío y nadie se entera hasta que un paquete retenido viaja sin motivo.
#
# ── Cómo sirve a los cinco ────────────────────────────────────────────────
#
# Los nombres de los campos salen del form builder, así que el mismo componente
# funciona suelto (`paquete[motivo_retencion_ids][]`) y anidado
# (`pre_alerta[pre_alerta_paquetes_attributes][0][motivo_retencion_ids][]`),
# incluido el `<template>` con `child_index: "NEW_INDEX"` de la pre-alerta. Por
# eso los motivos van con `collection_check_boxes` y no con `check_box_tag` y el
# `name` a mano, que era justamente lo que impedía compartir el bloque.
#
# `motivos` se recibe y no se consulta acá: el catálogo lo carga el controller,
# como todo lo demás. La copia que lo consultaba sola es la que se había
# separado.
class RetenerMiamiComponent < ViewComponent::Base
  def initialize(f:, motivos:)
    @f = f
    @motivos = motivos || []
  end

  attr_reader :f, :motivos

  def hay_motivos? = motivos.any?

  # El badge de "activo" sale cuando el objeto ya venía retenido. Sirve para el
  # paquete y para el renglón de la pre-alerta: los dos responden igual.
  def activo? = f.object.retener_miami?
end
