// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

if (window.Turbo && typeof window.Turbo.setConfirmMethod === "function") {
  window.Turbo.setConfirmMethod((message) => {
    if (typeof window.cecConfirm === "function") {
      return window.cecConfirm(message)
    }
    return Promise.resolve(window.confirm(message))
  })
}
