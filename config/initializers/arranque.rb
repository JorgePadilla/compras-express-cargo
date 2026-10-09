# PR-C29.16 · Cuándo arrancó este proceso, para «Arriba desde» en los signos
# del servidor. Se anota al cargar la app; un deploy o un reinicio de Render
# la vuelven a escribir.
Rails.application.config.x.arrancado_en = Time.current
