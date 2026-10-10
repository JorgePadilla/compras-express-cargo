# PR-F1.4 · Fase 15. El pie «Esta factura es valida como comprobante fiscal»
# sale de `empresas.terminos_factura`, en **todos** los entornos.
#
# Lo puso la semilla del arranque (`db/seeds.rb`) y nunca fue cierto: lo que
# hace válido un comprobante es el CAI, el rango y la fecha límite de la SAR
# (Acuerdo 481-2017, Arts. 10 y 59), y las facturas que salen hoy no los
# tienen. Hasta que salga la primera factura SAR, ese texto dice lo contrario
# de la verdad en cada PDF.
#
# Solo se borra si el texto **empieza** con esa leyenda: un pie que alguien
# escribió a mano se respeta. Por SQL y no con el modelo: una validación nueva
# de Empresa (p. ej. el ISV de F2.1) no tiene por qué trabar esta limpieza.
class QuitarLeyendaFalsaDeLaFactura < ActiveRecord::Migration[8.0]
  def up
    borradas = execute(<<~SQL).cmd_tuples
      UPDATE empresas
         SET terminos_factura = NULL, updated_at = CURRENT_TIMESTAMP
       WHERE terminos_factura ILIKE 'Esta factura es v_lida como comprobante fiscal%'
    SQL
    say "leyenda falsa quitada de #{borradas} empresa(s)"
  end

  # No se vuelve a poner un texto falso.
  def down; end
end
