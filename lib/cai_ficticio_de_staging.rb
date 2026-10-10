# PR-F1.5 · Fase 15. Un CAI inventado por sucursal de Honduras, para poder
# facturar en staging antes de tener el CAI real.
#
# Jorge, 2026-10-10: *sin CAI real todavía; CAI ficticio solo en staging, por
# migración de datos*. Migración porque el deploy solo migra, no siembra
# (`render.yaml` → `preDeployCommand: bundle exec rails db:migrate`): un
# catálogo que vive solo en `db/seeds.rb` nace vacío en staging. `db/seeds.rb`
# llama lo mismo para una base de dev nueva, y la lista vive acá para que las
# dos no se separen.
#
# ── Los frenos, en orden ──────────────────────────────────────────────────
#
# 1. `SEED_SAMPLE_DATA` presente: solo staging lo tiene (render.yaml). Lo exige
#    la migración; los seeds ya están adentro de su propio guard de datos de
#    muestra, que también deja pasar a development.
# 2. El host no es el de producción. Staging y producción corren las dos con
#    `RAILS_ENV=production`; si alguien le pusiera `SEED_SAMPLE_DATA` a
#    producción, esto igual no siembra. El modelo tampoco aceptaría la ficticia.
# 3. `autorizaciones_sar` vacía: si alguien ya cargó una por la pantalla
#    (F1.3), no se le agrega nada encima.
#
# ── Lo que crea ───────────────────────────────────────────────────────────
#
# Por cada sucursal activa de Honduras con número asignado en `PUNTOS`: su
# punto de emisión (o el que ya tenga), una autorización ficticia de facturas
# (tipo 01) con rango 1–5000 y vence en un año, y el correlativo en cero. La
# dirección de la sucursal y la razón social de la empresa, con un texto que
# dice que falta, **solo si están vacías**: el emisor de la factura las pide.
module CaiFicticioDeStaging
  # ❓ Casa matriz: el Acuerdo 481-2017 le da el establecimiento 000. Se asume
  # que es SPS (Zeron), donde está la dirección de la empresa; está preguntado
  # (Q5 de FISCAL.md). En staging no importa, el CAI es inventado igual.
  PUNTOS = {
    "SPS" => { establecimiento: "000", punto: "001" },
    "TGU" => { establecimiento: "001", punto: "001" },
    "SAM" => { establecimiento: "002", punto: "001" }
  }.freeze

  TIPO = "01".freeze
  RANGO = (1..5000)

  DIRECCION_PENDIENTE = "Dirección pendiente: cargarla en Sucursales".freeze
  RAZON_SOCIAL_PENDIENTE = "Razón social pendiente: cargarla en Empresa".freeze

  # `motivo`: `:sembrado`, o el freno que lo paró.
  Resultado = Data.define(:motivo, :autorizaciones) do
    def sembrado? = motivo == :sembrado
  end

  def self.cai_para(codigo) = "FICTICIO-STAGING-#{codigo}-0001"

  def self.sembrar!(exigir_datos_de_muestra: true)
    freno = freno(exigir_datos_de_muestra)
    return Resultado.new(motivo: freno, autorizaciones: []) if freno

    creadas = []
    AutorizacionSar.transaction do
      Sucursal.activas.where(ubicacion: "honduras", codigo: PUNTOS.keys).order(:codigo).each do |sucursal|
        punto = punto_para(sucursal) or next

        sucursal.update!(direccion: DIRECCION_PENDIENTE) if sucursal.direccion.blank?
        CorrelativoFiscal.find_or_create_by!(punto_de_emision: punto, tipo_documento: TIPO)
        creadas << AutorizacionSar.create!(
          punto_de_emision: punto, tipo_documento: TIPO, cai: cai_para(sucursal.codigo),
          rango_inicio: RANGO.first, rango_fin: RANGO.last,
          fecha_autorizacion: Fiscal.hoy, fecha_limite_emision: Fiscal.hoy + 1.year,
          ficticia: true
        )
      end

      empresa = Empresa.instance
      empresa.update!(razon_social: RAZON_SOCIAL_PENDIENTE) if creadas.any? && empresa.razon_social.blank?
    end

    Resultado.new(motivo: :sembrado, autorizaciones: creadas)
  end

  def self.freno(exigir_datos_de_muestra)
    if exigir_datos_de_muestra && ENV["SEED_SAMPLE_DATA"].blank? then :sin_datos_de_muestra
    elsif Fiscal.produccion? then :produccion
    elsif AutorizacionSar.exists? then :ya_hay_autorizaciones
    end
  end

  # El que la sucursal ya tenga, o uno nuevo con su número. Si el número ya lo
  # usa otra sucursal (alguien lo cargó a mano), esta se saltea: un deploy no
  # se cae por datos de prueba.
  def self.punto_para(sucursal)
    return sucursal.punto_de_emision if sucursal.punto_de_emision

    numeros = PUNTOS.fetch(sucursal.codigo)
    return nil if PuntoDeEmision.exists?(numeros)

    PuntoDeEmision.create!(sucursal: sucursal, **numeros)
  end
  private_class_method :punto_para, :freno
end
