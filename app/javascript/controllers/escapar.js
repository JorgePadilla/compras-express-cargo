// Escapar antes de volver a meter algo en `innerHTML`.
//
// Los JSON de búsqueda ya vienen escapados del servidor (`ERB::Util.html_escape`
// en `clientes#buscar` y compañía). Pero el `dataset` de una fila los
// **decodifica**: `data-nombre="&lt;img…"` se lee como `<img…`. El que vuelve a
// pintar un dato del `dataset` con `innerHTML` tiene que escapar de nuevo. No
// es un controller (no termina en `_controller`).
export function esc(valor) {
  return String(valor ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}
