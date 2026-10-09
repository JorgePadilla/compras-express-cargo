# Las pre-alertas que se contradicen con su servicio.
#
# Jorge, 2026-08-20: *"faltan las reglas de servicio, que son importantísimas"*.
# Antes de que existieran, admin podía marcar «con reempaque» y «consolidado»
# sobre cualquier servicio — incluidos CKA y CKM, que ni reempacan ni consolidan.
#
# La lógica vive en `PreAlerta.alinear_con_su_servicio!` y no acá: un método se
# puede testear —incluida la idempotencia— y un archivo de migración no.
#
# No toca las anuladas, las facturadas ni las borradas: ahí el dato es historia
# de lo que se cobró.
class AlinearPreAlertasConSuServicio < ActiveRecord::Migration[8.0]
  def up
    corregidas = PreAlerta.alinear_con_su_servicio!

    corregidas.each { |numero, arreglos| say "#{numero}: #{arreglos}" }
    say "#{corregidas.size} pre-alertas alineadas con su servicio"
  end

  def down
    say "no se deshace: eran datos que contradecían a su propio servicio"
  end
end
