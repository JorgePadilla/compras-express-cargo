# PR-F1.1 · `Fiscal.produccion?` lee `RAILS_ENV` y `APP_HOST`. Los tests que lo
# necesitan los cambian solo durante el bloque y los dejan como estaban (los
# workers en paralelo son procesos aparte: no se pisan entre sí).
module ConAppHost
  def con_app_host(host)
    antes = ENV["APP_HOST"]
    host.nil? ? ENV.delete("APP_HOST") : ENV["APP_HOST"] = host
    yield
  ensure
    antes.nil? ? ENV.delete("APP_HOST") : ENV["APP_HOST"] = antes
  end

  # Un servidor con `RAILS_ENV=production` (staging y producción lo son las
  # dos) y el `APP_HOST` que se le pase.
  def en_servidor(host, &)
    antes = Rails.env
    Rails.env = "production"
    con_app_host(host, &)
  ensure
    Rails.env = antes
  end

  def en_produccion(&) = en_servidor(Fiscal::HOST_DE_PRODUCCION, &)
  def en_staging(&) = en_servidor(Fiscal::HOST_DE_STAGING, &)
end
