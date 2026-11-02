module HistorialManifiestosHelper
  # Lo que quedó aplicado, en texto, para la barra de los filtros plegados del
  # historial (Jorge, 2026-10-24: *"ocultar o minimizar los filtros una vez
  # que presionamos buscar"*). Plegados no se ven, así que la barra tiene que
  # decir qué se está mirando: si no, una lista corta parece un historial
  # vacío. Devuelve las partes sueltas; la vista las une, y ERB las escapa —
  # el `q` lo escribe el usuario.
  def resumen_de_filtros_del_historial(estados:, empresas:, tipo_envios:)
    [
      (%(«#{params[:q]}») if params[:q].present?),
      resumen_de_estados(estados),
      empresas.find { |e| e.id.to_s == params[:empresa_manifiesto_id].to_s }&.nombre,
      { "oficial" => "Oficial", "interno" => "Interno" }[params[:tipo]],
      tipo_envios.select { |t| Array(params[:tipo_envio_ids]).include?(t.id.to_s) }.map(&:nombre).join(", ").presence,
      resumen_del_periodo
    ].compact
  end

  private

  def resumen_de_estados(estados)
    todos = HistorialManifiestosController::ESTADOS
    return "Todos los estados" if estados.size == todos.size

    todos.select { |valor, _| estados.include?(valor) }.map(&:last).join(", ")
  end

  # Las mismas reglas que `HistorialManifiestosController#por_fecha`: desde /
  # hasta manda sobre la ventana.
  def resumen_del_periodo
    desde = fecha_del_filtro(params[:desde])
    hasta = fecha_del_filtro(params[:hasta])
    return [ desde, hasta ].map { |f| f&.strftime("%d/%m/%Y") || "…" }.join(" – ") if desde || hasta

    if params[:incluir_mas_1_ano] == "1" then "Todas las fechas"
    elsif params[:incluir_3_12_meses] == "1" then "Último año"
    else "Últimos 3 meses"
    end
  end

  def fecha_del_filtro(valor)
    Date.iso8601(valor.to_s) if valor.present?
  rescue Date::Error
    nil
  end
end
