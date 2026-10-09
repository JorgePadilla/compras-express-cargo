# PR-C29.16 · Los signos del servidor.
#
# Jorge, 2026-10-08: *"pon un icono en / root y al lado derecho para ver los
# signos del servidor: ram, disco duro y cualquier otra cosa que sea
# importante, colas, queues tal vez"* · *"en una página, signos del servidor o
# algo así"*. Lo que se mide y por qué vive en `SignosVitales`.
class SignosVitalesController < ApplicationController
  before_action :autorizar

  def show
    @signos = SignosVitales.new
  end

  private

  # Por `can_access?` y no por `require_admin`: toda regla de rol vive en
  # `PermisosDelSistema` (`permisos_en_una_sola_fuente_test`).
  def autorizar
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:signos_vitales)
  end
end
