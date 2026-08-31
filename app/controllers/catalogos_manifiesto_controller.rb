# C21-08 · El portal de catálogos del manifiesto.
#
# Yusef, 2026-08-29, después de explicar el manifiesto entero:
#
#   > "Lo que yo te digo: que un CRUD para todo, para todo lo del manifiesto."
#   > "Si vos creás una [pantalla] donde yo pueda crear las empresas, los tipos
#   >  de envío que manejamos, la empresa que lo envía, qué consignatario somos
#   >  nosotros… que pueda yo crear estos, las cajas, los tamaños de las cajas,
#   >  en un solo [lugar]."
#   > "Como un portal, por decirte algo… pero que todo esté ahí, porque así uno
#   >  no tiene que andar buscando."
#
# El «no tener que andar buscando» es el requisito, no un adorno: por eso los
# cuatro catálogos viven en **una** pantalla con solapas y no en cuatro entradas
# sueltas del menú. Cada solapa es una tabla; crear y editar van a su CRUD y
# vuelven acá con la solapa puesta.
#
# **Es admin-only, y vive en Configuración** desde que Jorge lo mandó ahí el
# 2026-08-30. Arrancó abierto al equipo de Miami, razonando que el pedido era
# poder delegar —*"andate al área donde dice empresa, agregame esta empresa que
# voy a usar"*— y que un portal admin-only *"cumpliría la letra y fallaría el
# propósito"*.
#
# Lo que cerró el círculo fue el organigrama que Yusef dictó ese mismo día: a
# quien delega es a **Manal y Vanesa**, que *"tienen todos los poderes en el
# sistema"* — o sea admin. Michelle, el nombre que aparece en la cita, está dos
# niveles abajo y él mismo dijo que no carga catálogos.
class CatalogosManifiestoController < ApplicationController
  before_action :authorize_catalogos

  SOLAPAS = %w[empresas tipos_proveedor consignatarios tamanos].freeze

  def show
    @solapa = SOLAPAS.include?(params[:tab]) ? params[:tab] : SOLAPAS.first

    @empresas        = EmpresaManifiesto.order(:nombre)
    @tipos_proveedor = TipoEnvioProveedor.ordered
    @consignatarios  = Consignatario.ordered
    @tamanos         = TamanoCaja.ordered
  end

  private

  def authorize_catalogos
    # C21-08 · El portal vive en **Configuración** desde 2026-08-30, y ese
    # bloque es admin-only. Va por `can_access?` y no por una lista de roles
    # escrita acá: la misma línea estaba copiada en los cinco controllers del
    # portal y así fue como se desincronizaron antes.
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:catalogos_manifiesto)
  end
end
