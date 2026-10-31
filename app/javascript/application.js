// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "controllers/mensajes_de_validacion"
// C31-03 · «Le di muy rápido dos veces… y mandó la versión dos veces».
import "controllers/un_solo_envio"

if (window.Turbo && typeof window.Turbo.setConfirmMethod === "function") {
  // C34-02 · Turbo 8 pasa también el formulario y el botón que lo envió. Un
  // botón con `data-confirm-foco="confirmar"` abre el modal con el foco en
  // «Confirmar»: Yusef, finalizando un manifiesto, *"le di enter y dice
  // cancelar… debería ser al revés"*. Lo que borra sigue abriendo en
  // «Cancelar» (PR-A11Y.1).
  window.Turbo.setConfirmMethod((message, element, submitter) => {
    if (typeof window.cecConfirm === "function") {
      const foco = submitter?.dataset?.confirmFoco || element?.dataset?.confirmFoco
      return window.cecConfirm(message, foco === "confirmar" ? { foco: "confirmar", danger: false } : {})
    }
    return Promise.resolve(window.confirm(message))
  })
}
