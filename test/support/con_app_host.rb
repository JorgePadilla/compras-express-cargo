# PR-F1.1 · `Fiscal.produccion?` lee `APP_HOST`. Los tests que lo necesitan lo
# cambian solo durante el bloque y lo dejan como estaba (los workers en paralelo
# son procesos aparte: no se pisan entre sí).
module ConAppHost
  def con_app_host(host)
    antes = ENV["APP_HOST"]
    host.nil? ? ENV.delete("APP_HOST") : ENV["APP_HOST"] = host
    yield
  ensure
    antes.nil? ? ENV.delete("APP_HOST") : ENV["APP_HOST"] = antes
  end

  def en_produccion(&) = con_app_host(Fiscal::HOST_DE_PRODUCCION, &)
end
