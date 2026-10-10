require "open3"
require "timeout"

# PR-C29.16 · Los signos del servidor, para la pantalla de admin.
#
# Jorge, 2026-10-08: *"pon un icono en / root y al lado derecho para ver los
# signos del servidor: ram, disco duro y cualquier otra cosa que sea
# importante, colas, queues tal vez"* · *"en una página, signos del servidor o
# algo así"*.
#
# Hasta acá nada medía la máquina: la píldora «Operación saludable» del Home
# es de **negocio** (ventas pendientes y tareas abiertas, `DashboardMetrics`).
#
# Cuatro secciones:
#
#   · **El servidor web** — la RAM del contenedor (cgroup v2, o v1, o
#     `/proc/meminfo` si no hay cgroup), lo que ocupa este proceso, el disco,
#     la carga y cuánto lleva arriba. Es el contenedor **web**: el worker de la
#     cola es otro servicio de Render y su RAM no se ve desde acá. Al worker se
#     lo ve por la cola.
#   · **La base** — tamaño, las tablas más grandes, conexiones contra el máximo
#     de Postgres, y el pool de Rails.
#   · **La cola** — listos, programados, corriendo, fallidos (los últimos con su
#     error), workers vivos por su latido, y la última corrida de cada tarea de
#     la noche.
#   · **La app** — versión, entorno, sesiones y cambios de la última hora.
#
# **Nada de esto puede tumbar la pantalla.** Cada medida va con `rescue` y, si
# no se puede leer —en una Mac no hay `/proc`; en un contenedor puede faltar un
# archivo—, dice «no disponible». Lo que se lee de la máquina entra por
# `fuente:`, así los tests le dan archivos de mentira.
#
# **Lo que no se muestra, a propósito:** ninguna variable de entorno salvo el
# commit (corto) y `Rails.env`, ni direcciones, ni nombres de base. El
# `hostname` de los procesos de la cola sí: es lo único que distingue un worker
# de otro.
class SignosVitales
  # El orden importa: el peor gana.
  NIVELES = %i[bien mirar problema].freeze

  # Cómo se pinta cada nivel: los tonos de `ModalHeaderComponent`, que son la
  # regla de color de la app desde PR-C29.12 (rojo bloquea, oro pide atención,
  # teal es listo).
  TONO = { bien: :listo, mirar: :atencion, problema: :bloqueo }.freeze
  TITULO = { bien: "Todo bien", mirar: "Para mirar", problema: "Hay un problema" }.freeze

  # Los umbrales, en un solo lugar.
  RAM_MIRAR = 75
  RAM_PROBLEMA = 90
  # El disco de la máquina de Render: compartida, y vive alrededor del 83 %
  # (staging, 2026-10-09). Se mira igual —si se llena, la app se cae con
  # ella— pero con la vara de una máquina compartida.
  DISCO_MAQUINA_MIRAR = 90
  DISCO_MAQUINA_PROBLEMA = 95
  CONEXIONES_MIRAR = 80
  CONEXIONES_PROBLEMA = 95
  LATIDO_VIVO = 5.minutes
  NOCTURNA_ATRASADA = 26.hours
  FALLIDOS_A_MOSTRAR = 5
  # El mismo default que `config/puma.rb` (`ENV.fetch("RAILS_MAX_THREADS", 3)`).
  HILOS_DE_PUMA_POR_DEFECTO = 3

  NO_DISPONIBLE = "no disponible".freeze

  Medida = Struct.new(:nombre, :valor, :detalle, :porcentaje, :nivel, keyword_init: true)
  Fila = Struct.new(:titulo, :detalle, :cuando, :nivel, keyword_init: true)

  Seccion = Struct.new(:clave, :titulo, :medidas, :filas, :titulo_filas, :nota, keyword_init: true) do
    def nivel = SignosVitales.peor((medidas + filas).map(&:nivel))
  end

  # Lo que se lee de la máquina. Los tests le pasan una con archivos propios.
  class Fuente
    def leer(ruta) = File.read(ruta)

    def df(ruta = "/")
      salida, estado = Open3.capture2("df", "-Pk", ruta)
      raise "df salió con #{estado.exitstatus}" unless estado.success?

      salida
    end

    def nucleos = Etc.nprocessors

    def puma_stats = defined?(::Puma) && ::Puma.respond_to?(:stats_hash) ? ::Puma.stats_hash : nil

    # `du -xk -d 1 <ruta>`: KB por carpeta de primer nivel, sin salirse del
    # sistema de archivos (`-x` deja afuera /proc y /sys). Con tope de tiempo:
    # recorrer las gemas puede tardar, y la página no se puede quedar colgada.
    # Lo que no se puede leer se ignora (stderr al tacho).
    def du_por_carpeta(ruta = "/", segundos: 20)
      salida = +""
      Open3.popen3("du", "-xk", "-d", "1", ruta.to_s) do |entrada, out, err, espera|
        entrada.close
        Thread.new { err.read }
        begin
          Timeout.timeout(segundos) { salida = out.read }
        rescue Timeout::Error
          Process.kill("KILL", espera.pid) rescue nil
          raise
        end
      end
      salida.lines.filter_map do |linea|
        kb, carpeta = linea.chomp.split("\t", 2)
        [ kb.to_i, carpeta ] if carpeta
      end
    end

    # Lo que ocupan **nuestras** carpetas, en KB. `df` mide la máquina.
    def du(*rutas)
      existentes = rutas.map(&:to_s).select { |r| File.exist?(r) }
      return 0 if existentes.empty?

      salida, estado = Open3.capture2("du", "-sk", *existentes)
      raise "du salió con #{estado.exitstatus}" unless estado.success?

      salida.lines.sum { |l| l.split.first.to_i }
    end
  end

  # La fuente de verdad de la máquina. Los tests la cambian por una falsa: en
  # una Mac, `du /` tarda minutos.
  class_attribute :fuente_por_defecto, default: nil

  def self.fuente = fuente_por_defecto || Fuente.new

  # ── ¿Qué ocupa nuestro contenedor? ───────────────────────────────────
  #
  # Jorge, 2026-10-09: *"I want to know what is taking the disk space"*. De
  # los 243 GB de la máquina de Render solo se puede ver lo nuestro: cada
  # contenedor ve sus archivos y no los de los demás. Esto suma lo nuestro por
  # carpeta, y lo pone al lado del total de la máquina: la diferencia es de
  # otros servicios.
  Disco = Struct.new(:carpetas, :total, :maquina_usados, :maquina_total, keyword_init: true) do
    def de_otros = maquina_usados && total ? [ maquina_usados - total, 0 ].max : nil
  end

  CARPETAS_A_MOSTRAR = 12

  def self.disco_del_contenedor(fuente: self.fuente)
    filas = fuente.du_por_carpeta("/")
    raiz = filas.find { |_, carpeta| carpeta == "/" }
    carpetas = filas.reject { |_, carpeta| carpeta == "/" }.sort_by { |kb, _| -kb }.first(CARPETAS_A_MOSTRAR)
    usados, total = begin
      linea = fuente.df("/").lines.last.split
      [ linea[2].to_i * 1024, (linea[2].to_i + linea[3].to_i) * 1024 ]
    rescue StandardError
      [ nil, nil ]
    end
    Disco.new(carpetas: carpetas.map { |kb, carpeta| [ carpeta, kb * 1024 ] },
              total: raiz && raiz.first * 1024, maquina_usados: usados, maquina_total: total)
  end

  # Los fallidos se descartan con el método de solid_queue, que borra la
  # ejecución fallida y su job. Para cuando el error ya se arregló y los
  # intentos viejos solo tapan el semáforo (2026-10-09: 32 de la limpieza de
  # la noche, arreglada en PR-C29.19). Devuelve cuántos había.
  def self.descartar_fallidos!
    n = SolidQueue::FailedExecution.count
    SolidQueue::FailedExecution.discard_all_in_batches
    n
  end

  def self.peor(niveles)
    niveles.compact.max_by { |n| NIVELES.index(n) } || :bien
  end

  # Para el puntito del Home: **barato**. Solo la cola y las conexiones —dos
  # o tres `COUNT`—, sin `df` ni archivos, para que el Home no se haga lento
  # por mostrar un color.
  def self.nivel_rapido
    signos = new
    peor([ signos.send(:nivel_de_la_cola_rapido), signos.send(:conexiones).nivel ])
  rescue StandardError
    :mirar
  end

  def initialize(fuente: self.class.fuente, ahora: Time.current)
    @fuente = fuente
    @ahora = ahora
  end

  def secciones
    @secciones ||= [ servidor, base, cola, app ]
  end

  def nivel = self.class.peor(secciones.map(&:nivel))

  # Para el botón de descartar: solo aparece si hay algo que descartar.
  def fallidos_pendientes
    cola_de_verdad? ? SolidQueue::FailedExecution.count : 0
  rescue StandardError
    0
  end

  private

  # ── El servidor web ───────────────────────────────────────────────────

  def servidor
    Seccion.new(
      clave: :servidor, titulo: "Servidor web",
      medidas: [ ram, memoria_del_proceso, disco_de_la_app, cpu_del_contenedor, arriba_desde, puma,
                 disco_de_la_maquina, carga_de_la_maquina ],
      filas: [],
      nota: "Es el contenedor web. El worker de la cola es otro servicio: se lo ve en «Cola de trabajos». " \
            "Los dos últimos son de la máquina de Render, compartida con otros servicios: no los llenamos " \
            "nosotros, pero si revientan la app se cae con ellos, así que cuentan para el semáforo. " \
            "render.yaml pide 2 procesos de Puma (WEB_CONCURRENCY), pero " \
            "config/puma.rb no tiene `workers`: corre uno solo."
    )
  end

  def ram
    usada, total, origen = ram_del_contenedor
    porcentaje = (usada * 100.0 / total).round(1)
    Medida.new(nombre: "RAM", valor: "#{humano(usada)} de #{humano(total)}", detalle: origen,
               porcentaje: porcentaje, nivel: por_umbral(porcentaje, RAM_MIRAR, RAM_PROBLEMA))
  rescue StandardError
    no_disponible("RAM")
  end

  # cgroup v2, después v1, después la máquina entera. Un límite «max» (v2) o
  # gigantesco (v1, 2^63 redondeado) quiere decir que el contenedor no tiene
  # tope propio, y entonces el tope es la RAM de la máquina.
  #
  # 2026-10-10 · Jorge, mirando staging: *"why do we use so much memory?"* —476
  # de 512 MB, 93 %, en rojo— con Puma ocupando 222 MB. `memory.current` cuenta
  # también la **caché de archivos** del kernel (el código, las gemas, los
  # assets, los logs), que se suelta sola cuando la app pide memoria. Lo que se
  # mide es el *working set*, como Kubernetes y Render: lo usado menos
  # `inactive_file` de `memory.stat`, la caché que el kernel suelta primero.
  def ram_del_contenedor
    if (actual = leer_entero("/sys/fs/cgroup/memory.current"))
      limite = leer_limite("/sys/fs/cgroup/memory.max")
      cache = dato_de_memory_stat("/sys/fs/cgroup/memory.stat", "inactive_file")
      return [ actual - cache, limite || total_de_la_maquina, origen_con_cache("cgroup v2", cache) ]
    end

    if (actual = leer_entero("/sys/fs/cgroup/memory/memory.usage_in_bytes"))
      limite = leer_limite("/sys/fs/cgroup/memory/memory.limit_in_bytes")
      cache = dato_de_memory_stat("/sys/fs/cgroup/memory/memory.stat", "total_inactive_file")
      return [ actual - cache, limite || total_de_la_maquina, origen_con_cache("cgroup v1", cache) ]
    end

    info = meminfo
    total = info.fetch("MemTotal")
    [ total - info.fetch("MemAvailable"), total, "máquina (/proc/meminfo)" ]
  end

  # Un valor de `memory.stat` («inactive_file 123456»), o 0 si no está.
  def dato_de_memory_stat(ruta, clave)
    @fuente.leer(ruta)[/^#{clave}\s+(\d+)$/, 1].to_i
  rescue StandardError
    0
  end

  def origen_con_cache(cgroup, cache)
    return "contenedor (#{cgroup})" if cache.zero?

    "contenedor (#{cgroup}), sin #{humano(cache)} de caché de archivos que el kernel suelta solo"
  end

  def memoria_del_proceso
    rss = @fuente.leer("/proc/self/status")[/^VmRSS:\s+(\d+)\s+kB/, 1]
    raise "sin VmRSS" unless rss

    Medida.new(nombre: "Este proceso", valor: humano(rss.to_i * 1024), detalle: "memoria residente de Puma", nivel: :bien)
  rescue StandardError
    no_disponible("Este proceso")
  end

  # 2026-10-08 · Jorge, mirando staging: *"¿por qué el disco está tan lleno?"*
  # —240 GB de 290 GB, 82.9 %—. No era nuestro: `df /` adentro de un
  # contenedor de Render mide el disco de **la máquina**, compartida con otros
  # servicios, y Starter no tiene disco propio. Lo nuestro es lo que escribe la
  # app: `tmp/`, `log/` y `storage/` (si existiera). Eso es lo que se mide acá.
  # Es efímero: se borra en cada deploy.
  DISCO_DE_LA_APP_MIRAR = 1.gigabyte

  def disco_de_la_app
    kb = @fuente.du(Rails.root.join("tmp"), Rails.root.join("log"), Rails.root.join("storage"))
    bytes = kb * 1024
    Medida.new(nombre: "Disco de la app", valor: humano(bytes),
               detalle: "tmp/, log/ y storage/ · efímero: se borra en cada deploy; los datos viven en la base",
               nivel: bytes >= DISCO_DE_LA_APP_MIRAR ? :mirar : :bien)
  rescue StandardError
    no_disponible("Disco de la app")
  end

  # No lo llenamos nosotros, pero **se mira igual**. Jorge, 2026-10-09:
  # *"me parece que aunque no sean nuestros siempre hay que mirarlos, porque
  # si revientan muere la app"*. Con su propia vara (90 / 95 %): una máquina
  # compartida vive más llena que un disco propio.
  def disco_de_la_maquina
    linea = @fuente.df("/").lines.last.split
    usados = linea[2].to_i * 1024
    total = usados + linea[3].to_i * 1024
    porcentaje = (usados * 100.0 / total).round(1)
    Medida.new(nombre: "Disco de la máquina de Render", valor: "#{humano(usados)} de #{humano(total)}",
               detalle: "compartido con otros servicios: no lo llenamos nosotros, pero si se llena la app se cae",
               porcentaje: porcentaje,
               nivel: por_umbral(porcentaje, DISCO_MAQUINA_MIRAR, DISCO_MAQUINA_PROBLEMA))
  rescue StandardError
    no_disponible("Disco de la máquina de Render")
  end

  # Lo que nos toca de CPU: `cpu.max` de cgroup v2 es «cuota período»
  # (`50000 100000` = media CPU, el plan Starter). Sin tope, «max».
  def cpu_del_contenedor
    cuota, periodo = @fuente.leer("/sys/fs/cgroup/cpu.max").split
    valor = cuota == "max" ? "sin tope" : format("%g CPU", (cuota.to_f / periodo.to_f).round(2))
    Medida.new(nombre: "CPU del contenedor", valor: valor, detalle: "lo que el plan nos asigna (cgroup)", nivel: :bien)
  rescue StandardError
    no_disponible("CPU del contenedor")
  end

  # `/proc/loadavg` también es de la máquina entera, no del contenedor. Se
  # mira igual que el disco de la máquina: si la máquina se ahoga, nuestra
  # media CPU se ahoga con ella. Gold con la carga de 5 minutos por encima de
  # los núcleos; rojo al doble.
  def carga_de_la_maquina
    uno, cinco, quince = @fuente.leer("/proc/loadavg").split.first(3).map(&:to_f)
    nucleos = @fuente.nucleos
    nivel = if cinco > nucleos * 2 then :problema
            elsif cinco > nucleos then :mirar
            else :bien
            end
    Medida.new(nombre: "Carga de la máquina de Render", valor: format("%.2f · %.2f · %.2f", uno, cinco, quince),
               detalle: "1, 5 y 15 min · #{nucleos} #{nucleos == 1 ? 'núcleo' : 'núcleos'} compartidos con otros servicios",
               nivel: nivel)
  rescue StandardError
    no_disponible("Carga de la máquina de Render")
  end

  def arriba_desde
    desde = Rails.application.config.x.arrancado_en
    raise "sin hora de arranque" unless desde

    Medida.new(nombre: "Arriba desde", valor: I18n.l(desde, format: "%d/%m %H:%M"),
               detalle: "hace #{ApplicationController.helpers.time_ago_in_words(desde)}", nivel: :bien)
  rescue StandardError
    no_disponible("Arriba desde")
  end

  def puma
    stats = @fuente.puma_stats
    raise "sin estadísticas de Puma" unless stats

    # 2026-10-08 · En staging salía «? hilos»: las claves pueden venir como
    # texto o como símbolo según la versión, y sin ellas queda la config.
    stats = stats.deep_symbolize_keys
    procesos = stats[:workers].to_i.zero? ? 1 : stats[:workers]
    # Y si Puma no los da, los de `config/puma.rb`, con su mismo default: en
    # Render no hay `RAILS_MAX_THREADS` (solo `DATABASE_URL` y la master key),
    # así que corre con 3. Visto en staging el 2026-10-09: seguía «? hilos».
    hilos = stats[:max_threads] || stats.dig(:worker_status, 0, :last_status, :max_threads) ||
            ENV.fetch("RAILS_MAX_THREADS", HILOS_DE_PUMA_POR_DEFECTO)
    ocupados = stats[:busy_threads] || stats[:running] || stats.dig(:worker_status, 0, :last_status, :running)
    Medida.new(nombre: "Puma", valor: "#{procesos} #{procesos == 1 ? 'proceso' : 'procesos'} · #{hilos || '?'} hilos",
               detalle: ocupados ? "#{ocupados} atendiendo ahora" : nil,
               nivel: :bien)
  rescue StandardError
    no_disponible("Puma")
  end

  # ── La base ───────────────────────────────────────────────────────────

  def base
    Seccion.new(
      clave: :base, titulo: "Base de datos",
      medidas: [ tamano_de_la_base, conexiones, pool ],
      filas: tablas_mas_grandes, titulo_filas: "Las tablas más grandes"
    )
  end

  def tamano_de_la_base
    bytes = conexion.select_value("SELECT pg_database_size(current_database())").to_i
    Medida.new(nombre: "Tamaño", valor: humano(bytes), nivel: :bien)
  rescue StandardError
    no_disponible("Tamaño")
  end

  def conexiones
    @conexiones ||= begin
      usadas = conexion.select_value("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()").to_i
      maximo = conexion.select_value("SHOW max_connections").to_i
      porcentaje = (usadas * 100.0 / maximo).round(1)
      Medida.new(nombre: "Conexiones", valor: "#{usadas} de #{maximo}", detalle: "contra el máximo de Postgres",
                 porcentaje: porcentaje, nivel: por_umbral(porcentaje, CONEXIONES_MIRAR, CONEXIONES_PROBLEMA))
    rescue StandardError
      no_disponible("Conexiones")
    end
  end

  def pool
    stat = ActiveRecord::Base.connection_pool.stat
    Medida.new(nombre: "Pool de Rails", valor: "#{stat[:busy]} ocupadas de #{stat[:size]}",
               detalle: stat[:waiting].to_i.positive? ? "#{stat[:waiting]} esperando conexión" : "nadie esperando",
               nivel: stat[:waiting].to_i.positive? ? :mirar : :bien)
  rescue StandardError
    no_disponible("Pool de Rails")
  end

  def tablas_mas_grandes
    conexion.select_rows(<<~SQL).map { |tabla, bytes| Fila.new(titulo: tabla, detalle: humano(bytes.to_i)) }
      SELECT relname, pg_total_relation_size(relid)
      FROM pg_catalog.pg_statio_user_tables
      ORDER BY 2 DESC
      LIMIT 5
    SQL
  rescue StandardError
    []
  end

  # ── La cola ───────────────────────────────────────────────────────────

  def cola
    unless cola_de_verdad?
      return Seccion.new(clave: :cola, titulo: "Cola de trabajos", medidas: [], filas: [],
                         nota: "En este entorno la cola corre adentro del proceso web (adaptador " \
                               "#{ActiveJob::Base.queue_adapter_name}): no hay worker que mirar.")
    end

    Seccion.new(
      clave: :cola, titulo: "Cola de trabajos",
      medidas: [ contar("Listos", SolidQueue::ReadyExecution), contar("Programados", SolidQueue::ScheduledExecution),
                 contar("Corriendo", SolidQueue::ClaimedExecution), fallidos, workers ],
      filas: fallidos_recientes + nocturnas, titulo_filas: "Fallidos y tareas de la noche"
    )
  end

  def cola_de_verdad? = ActiveJob::Base.queue_adapter_name.to_s == "solid_queue"

  def nivel_de_la_cola_rapido
    return :bien unless cola_de_verdad?

    self.class.peor([ fallidos.nivel, workers.nivel ])
  end

  def contar(nombre, modelo)
    Medida.new(nombre: nombre, valor: modelo.count.to_s, nivel: :bien)
  rescue StandardError
    no_disponible(nombre)
  end

  def fallidos
    @fallidos ||= begin
      n = SolidQueue::FailedExecution.count
      Medida.new(nombre: "Fallidos", valor: n.to_s, detalle: n.positive? ? "esperando que alguien los mire" : nil,
                 nivel: n.positive? ? :mirar : :bien)
    rescue StandardError
      no_disponible("Fallidos")
    end
  end

  # Un worker está vivo si latió en los últimos 5 minutos. Sin ninguno, nada de
  # lo que se encola —correos, avisos, las tareas de la noche— se hace.
  def workers
    @workers ||= begin
      vivos = SolidQueue::Process.where(kind: "Worker").where("last_heartbeat_at > ?", @ahora - LATIDO_VIVO)
      n = vivos.count
      Medida.new(nombre: "Workers vivos", valor: n.to_s,
                 detalle: n.zero? ? "ninguno latió en 5 minutos: lo encolado no se está haciendo" : vivos.pluck(:hostname).compact.uniq.join(", "),
                 nivel: n.zero? ? :problema : :bien)
    rescue StandardError
      no_disponible("Workers vivos")
    end
  end

  def fallidos_recientes
    SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(FALLIDOS_A_MOSTRAR).map do |fallido|
      Fila.new(titulo: fallido.job&.class_name || "trabajo", detalle: error_de(fallido.error),
               cuando: fallido.created_at, nivel: :mirar)
    end
  rescue StandardError
    []
  end

  # `error` llega ya como Hash (solid_queue lo deserializa) o como JSON. En
  # staging salía el Hash crudo: `to_s` lo volvía texto y el JSON no lo leía.
  def error_de(error)
    datos = error.is_a?(Hash) ? error : JSON.parse(error.to_s)
    clase = datos["exception_class"].to_s.split("::").last
    [ clase.presence, datos["message"] ].compact.join(": ").truncate(160)
  rescue JSON::ParserError
    error.to_s.truncate(160)
  end

  # La última corrida de cada tarea de la noche. Atrasada si pasaron más de 26
  # horas: corren una vez por día.
  def nocturnas
    SolidQueue::RecurringExecution.group(:task_key).maximum(:run_at).sort.map do |tarea, ultima|
      atrasada = ultima < @ahora - NOCTURNA_ATRASADA
      Fila.new(titulo: tarea, detalle: atrasada ? "no corre hace más de un día" : "corrió", cuando: ultima,
               nivel: atrasada ? :mirar : :bien)
    end
  rescue StandardError
    []
  end

  # ── La app ────────────────────────────────────────────────────────────

  def app
    Seccion.new(clave: :app, titulo: "La aplicación", medidas: [ version, sesiones, cambios ], filas: [])
  end

  def version
    commit = ENV["RENDER_GIT_COMMIT"].to_s.first(7).presence || "—"
    Medida.new(nombre: "Versión", valor: commit, detalle: "#{Rails.env} · Rails #{Rails.version} · Ruby #{RUBY_VERSION}", nivel: :bien)
  end

  def sesiones
    n = Session.where("created_at > ?", @ahora - 24.hours).count
    Medida.new(nombre: "Sesiones", valor: n.to_s, detalle: "iniciadas en las últimas 24 horas", nivel: :bien)
  rescue StandardError
    no_disponible("Sesiones")
  end

  def cambios
    n = PaperTrail::Version.where("created_at > ?", @ahora - 1.hour).count
    Medida.new(nombre: "Cambios", valor: n.to_s, detalle: "registros tocados en la última hora", nivel: :bien)
  rescue StandardError
    no_disponible("Cambios")
  end

  # ── Utilidades ────────────────────────────────────────────────────────

  def conexion = ActiveRecord::Base.connection

  def no_disponible(nombre, nivel: nil) = Medida.new(nombre: nombre, valor: NO_DISPONIBLE, nivel: nivel)

  def por_umbral(porcentaje, mirar, problema)
    return :problema if porcentaje >= problema
    return :mirar if porcentaje >= mirar

    :bien
  end

  def leer_entero(ruta)
    Integer(@fuente.leer(ruta).strip)
  rescue StandardError
    nil
  end

  # `max` (v2) o un número de 2^62 para arriba (v1): sin tope propio.
  def leer_limite(ruta)
    valor = @fuente.leer(ruta).strip
    return nil if valor == "max"

    numero = Integer(valor)
    numero >= 2**62 ? nil : numero
  rescue StandardError
    nil
  end

  def meminfo
    @meminfo ||= @fuente.leer("/proc/meminfo").lines.to_h do |linea|
      clave, valor = linea.split(":")
      [ clave.strip, valor.to_i * 1024 ]
    end
  end

  def total_de_la_maquina = meminfo.fetch("MemTotal")

  def humano(bytes) = ActiveSupport::NumberHelper.number_to_human_size(bytes, precision: 3)
end
