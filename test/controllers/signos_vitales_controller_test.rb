require "test_helper"

# PR-C29.16 · «Signos del servidor»: solo admin.
class SignosVitalesControllerTest < ActionDispatch::IntegrationTest
  def login_as(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "admin ve las cuatro secciones y el estado general" do
    login_as users(:admin)
    get signos_vitales_url
    assert_response :success

    %w[servidor base cola app].each { |clave| assert_select "section[data-seccion=#{clave}]" }
    assert_select "[data-nivel]"
    assert_select "turbo-frame#signos_vitales[data-controller=refresco]"
  end

  test "no muestra secretos: nada del DATABASE_URL ni de las claves" do
    login_as users(:admin)
    get signos_vitales_url
    assert_no_match(/postgres:\/\//, response.body)
    assert_no_match(/SECRET_KEY_BASE|RAILS_MASTER_KEY/, response.body)
  end

  test "un supervisor no entra" do
    login_as users(:supervisor_miami)
    get signos_vitales_url
    assert_redirected_to root_path
  end

  test "un digitador no entra" do
    login_as users(:digitador)
    get signos_vitales_url
    assert_redirected_to root_path
  end

  test "el Home le muestra el ícono al admin, con su semáforo" do
    login_as users(:admin)
    get root_url
    assert_select "a[href='#{signos_vitales_path}'][data-signos]"
  end

  test "el Home no le muestra el ícono a un supervisor" do
    login_as users(:supervisor_miami)
    get root_url
    assert_response :success
    assert_select "a[href='#{signos_vitales_path}']", count: 0
  end

  # 2026-10-09 · Jorge: *"I want to know what is taking the disk space"*. De
  # la máquina compartida solo se ve lo nuestro: se suma por carpeta y se
  # compara con el total. La fuente es falsa: en una Mac, `du /` tarda minutos.
  class DiscoFalso
    def du_por_carpeta(_ruta = "/") = [ [ 600 * 1024, "/opt" ], [ 900 * 1024, "/usr" ], [ 1600 * 1024, "/" ], [ 100 * 1024, "/tmp" ] ]
    def df(_ruta = "/") = "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/x #{290 * 1024 * 1024} #{243 * 1024 * 1024} #{47 * 1024 * 1024} 84% /\n"
  end

  test "el admin mide qué ocupa nuestro contenedor, y lo de otros servicios" do
    SignosVitales.fuente_por_defecto = DiscoFalso.new
    login_as users(:admin)
    get disco_signos_vitales_url
    assert_response :success
    assert_select "turbo-frame#disco_del_contenedor"
    assert_match "1.56 GB", response.body, "el total de nuestro contenedor"
    assert_match "243 GB de 290 GB", response.body
    assert_match "241 GB", response.body, "lo de otros servicios: 243 GB menos lo nuestro"
    assert_operator response.body.index("/usr"), :<, response.body.index("/opt"), "las carpetas van de la más grande a la más chica"
  ensure
    SignosVitales.fuente_por_defecto = nil
  end

  test "el desglose del disco es solo del admin" do
    login_as users(:supervisor_miami)
    get disco_signos_vitales_url
    assert_redirected_to root_path
  end

  # 2026-10-09 · Jorge dijo que sí a borrar los 32 fallidos viejos de la
  # limpieza de la noche (arreglada en PR-C29.19). Queda un botón.
  test "el admin descarta los trabajos fallidos" do
    job = SolidQueue::Job.create!(queue_name: "default", class_name: "CleanEmptyPreAlertasJob", arguments: "{}")
    SolidQueue::FailedExecution.create!(job: job, error: { exception_class: "RuntimeError", message: "x" }.to_json)
    login_as users(:admin)

    assert_difference -> { SolidQueue::FailedExecution.count }, -1 do
      delete descartar_fallidos_signos_vitales_url
    end
    assert_redirected_to signos_vitales_path
    assert_equal "Se descartaron 1 trabajo fallido.", flash[:notice]
  end

  test "un supervisor no descarta nada" do
    job = SolidQueue::Job.create!(queue_name: "default", class_name: "CleanEmptyPreAlertasJob", arguments: "{}")
    SolidQueue::FailedExecution.create!(job: job, error: { exception_class: "RuntimeError", message: "x" }.to_json)
    login_as users(:supervisor_miami)

    assert_no_difference -> { SolidQueue::FailedExecution.count } do
      delete descartar_fallidos_signos_vitales_url
    end
    assert_redirected_to root_path
  end
end
