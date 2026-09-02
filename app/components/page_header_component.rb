class PageHeaderComponent < ViewComponent::Base
  renders_many :actions

  # «Volver» tiene su propio lugar, y siempre va **primero**.
  #
  # Jorge: *"las flechas para ir para atrás están raras y siempre a la derecha de
  # los botones; me parece que tiene más sentido siempre estar a lo más izquierda"*.
  # Y tiene razón: atrás es izquierda, en todas las interfaces del mundo.
  #
  # Estaban a la derecha por una razón tonta: las acciones se renderizan en orden
  # de declaración, y «Volver» se declaraba último porque es lo último que uno
  # escribe. O sea que la posición dependía del orden en que alguien tipeó, no de
  # una decisión.
  #
  # Un slot propio lo vuelve **estructural**: no se puede poner en otro lado ni
  # olvidar, y una pantalla nueva lo hereda bien sin acordarse. Hay un lint que
  # traba que vuelva a colarse un `arrow-left` entre las acciones.
  renders_one  :back
  renders_one  :meta

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end
end
