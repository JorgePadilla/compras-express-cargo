# PR-F1.5 · Fase 15. El CAI inventado de staging, uno por sucursal de Honduras.
#
# Jorge, 2026-10-10: *sin CAI real todavía; CAI ficticio solo en staging, por
# migración de datos*. Va por migración porque el deploy solo migra y no
# siembra: en `db/seeds.rb` solo, staging se quedaría sin con qué facturar.
#
# Los frenos y lo que crea están en `lib/cai_ficticio_de_staging.rb`, que
# también llaman los seeds. En producción, en dev sin `SEED_SAMPLE_DATA` y
# donde ya haya una autorización cargada, no hace nada.
class SembrarCaiFicticioDeStaging < ActiveRecord::Migration[8.0]
  def up
    require Rails.root.join("lib/cai_ficticio_de_staging")
    [ Sucursal, Empresa, PuntoDeEmision, AutorizacionSar, CorrelativoFiscal ].each(&:reset_column_information)

    resultado = ::CaiFicticioDeStaging.sembrar!
    if resultado.sembrado?
      say "CAI ficticio: #{resultado.autorizaciones.map(&:cai).join(', ')}"
    else
      say "CAI ficticio: no se siembra (#{resultado.motivo})"
    end
  end

  # No se deshace: son datos de prueba, y bajarla borraría también lo que se
  # haya emitido con ellos en staging. Las tablas las saca la migración de F1.1.
  def down; end
end
