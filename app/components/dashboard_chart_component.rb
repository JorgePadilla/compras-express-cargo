class DashboardChartComponent < ViewComponent::Base
  WIDTH  = 800
  HEIGHT = 200
  PAD_X  = 24
  PAD_Y  = 24
  AXIS_H = 24

  # series: array of hashes con keys :label y :paquetes (orden cronológico).
  def initialize(series:)
    @series = series.to_a
    @values = @series.map { |d| d[:paquetes].to_i }
    @max    = @values.max.to_i
    @max    = 1 if @max.zero?
    @avg    = @values.empty? ? 0 : (@values.sum.to_f / @values.length).round
    @total  = @values.sum
    @peak   = @values.max
  end

  attr_reader :total, :peak, :avg

  def points
    @points ||= compute_points
  end

  # Path "M x,y C ... " smoothing por Catmull-Rom→Bezier.
  def smooth_path
    return "" if points.length < 2
    pts = points
    d = +"M #{fmt(pts[0][:x])},#{fmt(pts[0][:y])} "
    (0..pts.length - 2).each do |i|
      p0 = pts[i - 1] || pts[i]
      p1 = pts[i]
      p2 = pts[i + 1]
      p3 = pts[i + 2] || p2
      cp1x = p1[:x] + (p2[:x] - p0[:x]) / 6.0
      cp1y = p1[:y] + (p2[:y] - p0[:y]) / 6.0
      cp2x = p2[:x] - (p3[:x] - p1[:x]) / 6.0
      cp2y = p2[:y] - (p3[:y] - p1[:y]) / 6.0
      d << "C #{fmt(cp1x)},#{fmt(cp1y)} #{fmt(cp2x)},#{fmt(cp2y)} #{fmt(p2[:x])},#{fmt(p2[:y])} "
    end
    d.strip
  end

  # Path para el área bajo la curva: misma curva + cierre al baseline.
  def area_path
    return "" if points.length < 2
    base_y = HEIGHT - AXIS_H - PAD_Y
    "#{smooth_path} L #{fmt(points.last[:x])},#{base_y} L #{fmt(points.first[:x])},#{base_y} Z"
  end

  def avg_y
    plot_y(@avg)
  end

  def labels
    @series.map { |d| d[:label] }
  end

  def last_point
    points.last
  end

  def viewbox
    "0 0 #{WIDTH} #{HEIGHT}"
  end

  def chart_height
    HEIGHT
  end

  private

  def compute_points
    n = @values.length
    return [] if n.zero?
    step = n > 1 ? (WIDTH - PAD_X * 2).to_f / (n - 1) : 0
    @values.each_with_index.map do |v, i|
      { x: PAD_X + step * i, y: plot_y(v), value: v }
    end
  end

  def plot_y(value)
    plot_h = HEIGHT - AXIS_H - PAD_Y * 2
    PAD_Y + (1 - value.to_f / @max) * plot_h
  end

  def fmt(num)
    num.round(2).to_s
  end
end
