# PR-9.b: arma los bloques de notas de la franja de contexto.
#
# El orden lo definió Yusef como "la jerarquía de la empresa" (2026-08-01) y
# se resolvió como orden por departamento: Miami → Caja → Pre-Factura → SAC →
# Entrega. Pre-Factura y Entrega comparten `notas_honduras`, así que el orden
# efectivo de las notas permanentes es Miami → Caja → Honduras → SAC — eso lo
# garantiza `User::NOTAS_DEPARTAMENTO_ORDEN`.
module PanelContextoHelper
  # Tonos permitidos por el design system (ver docs/07 y el lint
  # test/lint/banned_colors_test.rb): solo navy · gold · teal · slate · amber.
  TONOS_NOTA = {
    navy:  { wrap: "bg-cec-navy/5 dark:bg-cec-navy/20 ring-cec-navy/20 dark:ring-cec-navy/40", label: "text-cec-navy dark:text-cec-gold" },
    amber: { wrap: "bg-amber-50 dark:bg-amber-900/20 ring-amber-300/60 dark:ring-amber-700/50", label: "text-amber-800 dark:text-amber-200" },
    teal:  { wrap: "bg-cec-teal/10 dark:bg-cec-teal/15 ring-cec-teal/30 dark:ring-cec-teal/40", label: "text-cec-teal-dark dark:text-cec-teal-light" },
    gold:  { wrap: "bg-cec-gold/10 dark:bg-cec-gold/15 ring-cec-gold/30 dark:ring-cec-gold/40", label: "text-cec-gold-dark dark:text-cec-gold-light" },
    slate: { wrap: "bg-slate-50 dark:bg-gray-700/50 ring-slate-200 dark:ring-gray-600", label: "text-slate-600 dark:text-slate-300" }
  }.freeze

  # Las 5 categorías de la hoja de Yusef, ya filtradas a las que tienen
  # contenido. Devuelve [] cuando el cliente no tiene ninguna nota.
  def notas_contexto_blocks(cliente:, paquete:, notas_especiales:, user:)
    blocks = []

    # 1. Notas especiales — instrucciones que el cliente escribió en su pre-alerta.
    Array(notas_especiales).each do |tracking, texto|
      blocks << nota_block("Nota especial", texto, :navy, detalle: tracking)
    end

    # 2. Notas permanentes del cliente — solo las del área del usuario, en
    #    orden por departamento.
    user&.notas_permanentes_visibles&.each do |n|
      blocks << nota_block("Nota permanente", cliente.public_send(n[:campo]), :amber, detalle: n[:etiqueta])
    end

    # 3-5. Notas del paquete, cuando el tracking ya existe en el sistema.
    if paquete
      blocks << nota_block("Notas de consolidación", paquete.notas_consolidacion, :teal)
      blocks << nota_block("Notas internas", paquete.notas_internas, :slate)
      blocks << nota_block("Notas al cliente", paquete.notas_al_cliente, :gold)
    end

    blocks.compact
  end

  def tono_nota_classes(tono)
    TONOS_NOTA.fetch(tono, TONOS_NOTA[:slate])
  end

  private

  def nota_block(etiqueta, texto, tono, detalle: nil)
    return nil if texto.blank?

    { etiqueta: etiqueta, detalle: detalle, texto: texto, tono: tono }
  end
end
