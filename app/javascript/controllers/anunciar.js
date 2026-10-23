// Decirle algo a un lector de pantalla sin moverle el foco.
//
// PR-A11Y.5. Los avisos de la app se pintaban en silencio: «Paquete guardado»
// en /etiquetar, el «ya está en este manifiesto» de la pistola, el «faltan 2»
// de /medicion. Se veían y sonaban, pero un lector de pantalla no se enteraba.
//
// Las dos regiones viven fijas en los layouts (`#aviso-lector` y
// `#aviso-lector-urgente`): una región `aria-live` tiene que existir ANTES de
// que cambie su texto, o el lector no la escucha. Si una pantalla sin layout
// la pide, se crea.
//
// No es un controller (no termina en `_controller`): es una función que
// importan los que la necesitan, como `busqueda_autocomplete.js`.
export function anunciar(texto, { urgente = false } = {}) {
  const limpio = (texto || "").replace(/\s+/g, " ").trim()
  if (!limpio) return

  const region = regionLector(urgente)
  // Se vacía antes de escribir: el mismo texto dos veces seguidas («Paquete
  // agregado», «Paquete agregado») tiene que volver a sonar.
  region.textContent = ""
  setTimeout(() => { region.textContent = limpio }, 50)
}

function regionLector(urgente) {
  const id = urgente ? "aviso-lector-urgente" : "aviso-lector"
  let region = document.getElementById(id)
  if (region) return region

  region = document.createElement("div")
  region.id = id
  region.className = "sr-only"
  region.setAttribute("role", urgente ? "alert" : "status")
  region.setAttribute("aria-live", urgente ? "assertive" : "polite")
  document.body.appendChild(region)
  return region
}
