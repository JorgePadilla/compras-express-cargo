# C19-06: la pantalla donde Yusef corre la etiqueta él mismo.
#
# "¿Vos no tenés en el sistema donde yo pueda cambiarlas yo?… a mí me habían
# dado esto [en el viejo] para hacer eso, para no molestar… con eso yo te
# quito a vos." Las Dymo se van de lado con el uso — "como arrancamos
# etiquetas a morir, créeme que más de alguna tira que se va de lado; en San
# Pedro le tuve que poner una tuerca" — y hasta hoy corregir el margen era un
# deploy. Patrón calcado de /tasa_cambio: claves en Configuracion (sin
# migración), historial de paper_trail, solo admin.
class AjustesEtiquetaController < ApplicationController
  before_action :require_admin

  def show
    @margen_izq = EtiquetaAjustes.margen_izq_mm
    @margen_der = EtiquetaAjustes.margen_der_mm
    ids = Configuracion.where(clave: [ EtiquetaAjustes::CLAVE_IZQ, EtiquetaAjustes::CLAVE_DER ]).pluck(:id)
    @historial = PaperTrail::Version
                   .where(item_type: "Configuracion", item_id: ids)
                   .order(created_at: :desc)
                   .limit(10)
  end

  def update
    izq = leer_mm(params[:margen_izq_mm])
    der = leer_mm(params[:margen_der_mm])

    if izq.nil? || der.nil?
      redirect_to ajustes_etiqueta_path,
                  alert: "Los márgenes van en milímetros, entre 0 y #{EtiquetaAjustes::MAX_MM}."
      return
    end

    Configuracion.set(EtiquetaAjustes::CLAVE_IZQ, izq.to_s("F"), tipo: "decimal", categoria: "etiqueta")
    Configuracion.set(EtiquetaAjustes::CLAVE_DER, der.to_s("F"), tipo: "decimal", categoria: "etiqueta")
    redirect_to ajustes_etiqueta_path,
                notice: "Márgenes guardados. Reimprimí una etiqueta para ver el corrimiento."
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin puede ajustar la etiqueta.") unless Current.user&.admin?
  end

  def leer_mm(crudo)
    valor = BigDecimal(crudo.to_s.strip.tr(",", "."), exception: false)
    return nil if valor.nil? || valor.negative? || valor > EtiquetaAjustes::MAX_MM

    valor
  end
end
