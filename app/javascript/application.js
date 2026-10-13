// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "controllers/mensajes_de_validacion"
// C31-03 · «Le di muy rápido dos veces… y mandó la versión dos veces».
import "controllers/un_solo_envio"

if (window.Turbo && typeof window.Turbo.setConfirmMethod === "function") {
  window.Turbo.setConfirmMethod((message) => {
    if (typeof window.cecConfirm === "function") {
      return window.cecConfirm(message)
    }
    return Promise.resolve(window.confirm(message))
  })
}
