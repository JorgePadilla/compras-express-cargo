require "test_helper"

# PR-C29.16 · Los signos del servidor, con archivos de mentira: la máquina de
# los tests no es la de Render, y una Mac ni siquiera tiene `/proc`.
class SignosVitalesTest < ActiveSupport::TestCase
  GB = 1024**3
  MB = 1024**2

  # Una máquina armada a mano: rutas → contenido, y la salida de `df`.
  class FuenteFalsa
    def initialize(archivos: {}, df: nil, nucleos: 2)
      @archivos = archivos
      @df = df
      @nucleos = nucleos
    end

    def leer(ruta) = @archivos.fetch(ruta) { raise Errno::ENOENT, ruta }
    def df(_ruta = "/") = @df || raise(Errno::ENOENT, "df")
    attr_reader :nucleos
  end

  def df_al(porcentaje)
    total_kb = 10 * 1024 * 1024
    usados = total_kb * porcentaje / 100
    "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/root #{total_kb} #{usados} #{total_kb - usados} #{porcentaje}% /\n"
  end

  def medida(signos, seccion, nombre)
    signos.secciones.find { |s| s.clave == seccion }.medidas.find { |m| m.nombre == nombre }
  end

  test "RAM del contenedor con cgroup v2" do
    signos = SignosVitales.new(fuente: FuenteFalsa.new(archivos: {
      "/sys/fs/cgroup/memory.current" => (400 * MB).to_s, "/sys/fs/cgroup/memory.max" => (512 * MB).to_s
    }))
    ram = medida(signos, :servidor, "RAM")
    assert_equal 78.1, ram.porcentaje
    assert_equal :mirar, ram.nivel
    assert_includes ram.detalle, "cgroup v2"
  end

  test "RAM con cgroup v1, y un límite gigante es «sin tope»: manda la máquina" do
    signos = SignosVitales.new(fuente: FuenteFalsa.new(archivos: {
      "/sys/fs/cgroup/memory/memory.usage_in_bytes" => (1 * GB).to_s,
      "/sys/fs/cgroup/memory/memory.limit_in_bytes" => "9223372036854771712",
      "/proc/meminfo" => "MemTotal: #{4 * 1024 * 1024} kB\nMemAvailable: #{3 * 1024 * 1024} kB\n"
    }))
    ram = medida(signos, :servidor, "RAM")
    assert_equal 25.0, ram.porcentaje
    assert_equal :bien, ram.nivel
    assert_includes ram.detalle, "cgroup v1"
  end

  test "sin cgroup, la RAM sale de /proc/meminfo; al 95 % es un problema" do
    signos = SignosVitales.new(fuente: FuenteFalsa.new(archivos: {
      "/proc/meminfo" => "MemTotal: 1000000 kB\nMemFree: 1000 kB\nMemAvailable: 50000 kB\n"
    }))
    ram = medida(signos, :servidor, "RAM")
    assert_equal 95.0, ram.porcentaje
    assert_equal :problema, ram.nivel
  end

  test "el disco al 50, 85 y 95 %" do
    { 50 => :bien, 85 => :mirar, 95 => :problema }.each do |porcentaje, nivel|
      signos = SignosVitales.new(fuente: FuenteFalsa.new(df: df_al(porcentaje)))
      assert_equal nivel, medida(signos, :servidor, "Disco").nivel, "disco al #{porcentaje} %"
    end
  end

  test "la carga por encima de los núcleos pide mirar" do
    alta = SignosVitales.new(fuente: FuenteFalsa.new(archivos: { "/proc/loadavg" => "3.10 2.90 1.00 2/300 1234" }, nucleos: 2))
    baja = SignosVitales.new(fuente: FuenteFalsa.new(archivos: { "/proc/loadavg" => "0.20 0.30 0.10 1/300 1234" }, nucleos: 2))
    assert_equal :mirar, medida(alta, :servidor, "Carga de CPU").nivel
    assert_equal :bien, medida(baja, :servidor, "Carga de CPU").nivel
  end

  test "lo que no se puede leer dice «no disponible», y la pantalla no se cae" do
    signos = SignosVitales.new(fuente: FuenteFalsa.new)
    servidor = signos.secciones.find { |s| s.clave == :servidor }
    %w[RAM Disco].each do |nombre|
      assert_equal SignosVitales::NO_DISPONIBLE, servidor.medidas.find { |m| m.nombre == nombre }.valor
    end
    assert_includes SignosVitales::NIVELES, signos.nivel
  end

  test "la base mide su tamaño y sus conexiones contra el máximo" do
    signos = SignosVitales.new(fuente: FuenteFalsa.new)
    assert_match(/\d/, medida(signos, :base, "Tamaño").valor)
    assert_match(/\A\d+ de \d+\z/, medida(signos, :base, "Conexiones").valor)
  end

  test "la cola: un fallido pide mirar, y sin worker vivo es un problema" do
    with_solid_queue do
      job = SolidQueue::Job.create!(queue_name: "default", class_name: "MarcarCuotasVencidasJob", arguments: "{}")
      SolidQueue::FailedExecution.create!(job: job, error: { exception_class: "RuntimeError", message: "se cayó" }.to_json)

      signos = SignosVitales.new(fuente: FuenteFalsa.new)
      assert_equal :mirar, medida(signos, :cola, "Fallidos").nivel
      assert_equal :problema, medida(signos, :cola, "Workers vivos").nivel
      fila = signos.secciones.find { |s| s.clave == :cola }.filas.first
      assert_equal "MarcarCuotasVencidasJob", fila.titulo
      assert_equal "RuntimeError: se cayó", fila.detalle
      assert_equal :problema, signos.nivel
    end
  end

  test "un worker que latió hace un minuto está vivo; uno de hace diez, no" do
    with_solid_queue do
      SolidQueue::Process.create!(kind: "Worker", name: "w-viejo", pid: 1, hostname: "srv-viejo", last_heartbeat_at: 10.minutes.ago)
      assert_equal :problema, medida(SignosVitales.new(fuente: FuenteFalsa.new), :cola, "Workers vivos").nivel

      SolidQueue::Process.create!(kind: "Worker", name: "w-nuevo", pid: 2, hostname: "srv-nuevo", last_heartbeat_at: 1.minute.ago)
      vivos = medida(SignosVitales.new(fuente: FuenteFalsa.new), :cola, "Workers vivos")
      assert_equal "1", vivos.valor
      assert_equal "srv-nuevo", vivos.detalle
    end
  end

  test "una tarea de la noche que no corre hace más de un día pide mirar" do
    with_solid_queue do
      job = SolidQueue::Job.create!(queue_name: "default", class_name: "CleanEmptyPreAlertasJob", arguments: "{}")
      SolidQueue::RecurringExecution.create!(job: job, task_key: "limpiar_pre_alertas", run_at: 30.hours.ago)
      fila = SignosVitales.new(fuente: FuenteFalsa.new).secciones.find { |s| s.clave == :cola }.filas.find { |f| f.titulo == "limpiar_pre_alertas" }
      assert_equal :mirar, fila.nivel
    end
  end

  test "sin solid_queue, la cola no se juzga: corre adentro del proceso" do
    signos = SignosVitales.new(fuente: FuenteFalsa.new)
    cola = signos.secciones.find { |s| s.clave == :cola }
    assert_empty cola.medidas
    assert_includes cola.nota, "no hay worker"
    assert_equal :bien, cola.nivel
  end

  test "nivel_rapido es la cola y las conexiones, sin leer la máquina" do
    assert_includes SignosVitales::NIVELES, SignosVitales.nivel_rapido
    with_solid_queue { assert_equal :problema, SignosVitales.nivel_rapido }
  end

  test "no muestra variables de entorno salvo el commit corto" do
    ENV["RENDER_GIT_COMMIT"] = "abcdef1234567890"
    version = medida(SignosVitales.new(fuente: FuenteFalsa.new), :app, "Versión")
    assert_equal "abcdef1", version.valor
  ensure
    ENV.delete("RENDER_GIT_COMMIT")
  end

  private

  # En test el adaptador no es solid_queue; para juzgar la cola se lo cambia
  # un rato, como en producción.
  def with_solid_queue
    anterior = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
    yield
  ensure
    ActiveJob::Base.queue_adapter = anterior
  end
end
