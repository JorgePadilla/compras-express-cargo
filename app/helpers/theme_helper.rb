module ThemeHelper
  # Devuelve "light", "dark" o "auto" segun la preferencia persistida del
  # usuario/cliente autenticado. Si no hay sesion, retorna "auto".
  def current_theme
    preferencia = Current.user&.tema.presence || Current.cliente&.tema.presence
    preferencia.presence || "auto"
  end

  # Clase inicial para el <html>: "dark" si el tema explicito es dark,
  # string vacio para light. Para "auto" retorna "" y el inline script del
  # layout decide client-side segun prefers-color-scheme (evita FOUC).
  def html_theme_class(theme = current_theme)
    theme == "dark" ? "dark" : ""
  end

  # URL del endpoint segun contexto (admin vs cliente). El toggle manda POST
  # a la ruta correspondiente.
  def theme_preferencia_url
    if Current.cliente.present?
      cuenta_preferencia_tema_path
    else
      preferencia_tema_path
    end
  end

  # Habilita el toggle solo cuando hay una sesion que pueda persistir el
  # cambio. Sin sesion el boton no se muestra.
  def theme_toggle_available?
    Current.user.present? || Current.cliente.present?
  end
end
