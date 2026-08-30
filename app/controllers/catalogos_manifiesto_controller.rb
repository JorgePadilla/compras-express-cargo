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
# **No es admin-only a propósito.** El pedido es poder delegar —*"andate al área
# donde dice empresa, agregame esta empresa que voy a usar"*, dicho sobre alguien
# de su equipo—, así que un portal que solo abre el admin cumpliría la letra y
# fallaría el propósito.
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
    # Miami y nada más. Se deriva de `Manifiesto::ROLES_DE_MIAMI` en vez de
    # escribirse cinco veces: esta misma línea estaba copiada en los cinco
    # controllers del portal, y `:manifiestos` —que era su llave— dejó de ser
    # solo de Miami cuando San Pedro entró a llenar la guía (`C21-02`).
    require_role(*Manifiesto::ROLES_DE_MIAMI)
  end
end
