# frozen_string_literal: true

# La gema `heroicon` declara su engine con `isolate_namespace`, así que su
# helper NO entra solo a las vistas de la app. Este módulo lo re-expone: al
# vivir en app/helpers, Rails lo incluye en el view context de todos los
# controllers.
#
# Se incluye `Heroicon::ApplicationHelper` **directamente** y no
# `Heroicon::Engine.helpers`. Ese método memoiza el módulo que arma
# (`@helpers ||= ...`), así que el resultado depende de en qué momento del
# arranque se lo llame por primera vez: si algo autocarga este archivo antes
# de que el engine termine de registrar sus helper paths, devuelve un módulo
# VACÍO y queda memoizado así para todo el proceso.
#
# El síntoma es `undefined method 'heroicon'` en cualquier vista, con la gema
# instalada y todo aparentemente en orden — y no se reproduce con
# `rails runner` ni en los tests, porque ahí el orden de carga es distinto.
module HeroiconHelper
  include Heroicon::ApplicationHelper
end
