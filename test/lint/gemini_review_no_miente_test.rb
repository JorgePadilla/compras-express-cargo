require "test_helper"
require "yaml"

# PR: que el check de Gemini no vuelva a salir verde sin haber revisado nada.
#
# El `jq` de la llamada tenía un fallback tipo `.candidates[0]…text // "Error:
# …"`: cuando la API contestaba 429, ese texto de error **se posteaba como si
# fuera el review** y el step salía con 0. En el PR se leía "🤖 Gemini Code
# Review" y el check decía verde. `PR-388` se mergeó así, con cero revisión.
#
# Es la peor forma de fallar que hay: no es que el review sea malo, es que **no
# existe y se ve igual que uno bueno**. Nadie va a abrir un check verde para
# comprobar que de verdad revisó.
#
# Este test lee el workflow y confronta las tres piezas que hacen que un review
# ausente se vea ausente.
class GeminiReviewNoMienteTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/gemini-review.yml")

  def pasos
    YAML.load_file(WORKFLOW)["jobs"]["review"]["steps"]
  end

  def paso(nombre)
    pasos.find { |p| p["name"] == nombre }
  end

  test "el error de la API no se puede disfrazar de review" do
    llamada = paso("Call Gemini API")
    refute_nil llamada, "el paso que llama a la API cambió de nombre"

    # `// "…"` sobre el texto del candidato es exactamente el patrón que
    # convertía la falla en contenido. `// empty` sí vale: deja la variable
    # vacía y el script decide qué hacer.
    disfraz = llamada["run"].scan(/\.candidates\[0\][^\n]*?\/\/\s*"/)
    assert_empty disfraz,
      "el fallback del jq vuelve a meter el error adentro del review:\n#{disfraz.join("\n")}"
  end

  test "cuando no hay review, el job termina en rojo" do
    # Se busca por la condición y no por el nombre ni por el orden: hay otro
    # `exit 1` antes (el que aborta si falta el `GEMINI_API_KEY`) y buscar el
    # primero encontraba ése.
    rojo = pasos.find { |p| p["if"].to_s.include?("steps.gemini.outputs.estado") }
    refute_nil rojo,
      "ningún paso mira el resultado de la llamada: un review ausente sale verde"
    assert_match(/\bexit 1\b/, rojo["run"].to_s,
      "el paso que mira el resultado no pone el check en rojo (`#{rojo['name']}`)")

    llamada = paso("Call Gemini API")
    assert_equal "gemini", llamada["id"],
      "el `if` del paso rojo apunta a `steps.gemini`, pero la llamada ya no tiene ese id"
    assert_includes llamada["run"], "estado=fallo",
      "la llamada nunca declara el fallo que el paso rojo está esperando"
  end

  test "el motivo llega al PR aunque la llamada haya fallado" do
    comentario = paso("Post review comment")
    refute_nil comentario, "el paso que comenta cambió de nombre"

    # Sin `always()`, GitHub saltea el comentario cuando el paso previo falla y
    # el check queda rojo **sin decir por qué** — que es igual de inútil que
    # verde sin revisar.
    assert_equal "always()", comentario["if"].to_s,
      "el comentario no corre si la llamada falla: el check quedaría rojo y mudo"
  end

  test "las aserciones de arriba de verdad miran algo" do
    # La trampa de este repo: un lint cuyo patrón dejó de coincidir pasa en
    # verde para siempre. Se rompe el workflow a propósito y se exige que el
    # test lo note.
    roto = YAML.load_file(WORKFLOW)
    roto["jobs"]["review"]["steps"] = roto["jobs"]["review"]["steps"].map do |p|
      p = p.dup
      p["run"] = p["run"].to_s.gsub("estado=fallo", "estado=ok") if p["name"] == "Call Gemini API"
      p.delete("if") if p["name"] == "Post review comment"
      p["if"] = "false" if p["if"].to_s.include?("steps.gemini.outputs.estado")
      p
    end

    rojo = roto["jobs"]["review"]["steps"].find { |p| p["if"].to_s.include?("steps.gemini.outputs.estado") }
    assert_nil rojo,
      "el sabotaje no pudo desconectar el paso rojo, así que ese test no lo estaba mirando"

    llamada = roto["jobs"]["review"]["steps"].find { |p| p["name"] == "Call Gemini API" }
    refute_includes llamada["run"], "estado=fallo",
      "el sabotaje no cambió nada: `estado=fallo` ya no está escrito así"

    comentario = roto["jobs"]["review"]["steps"].find { |p| p["name"] == "Post review comment" }
    assert_nil comentario["if"],
      "el sabotaje no pudo sacar el `if`, así que el test de arriba no lo estaba mirando"
  end
end
